#!/usr/bin/php
<?php
require_once('/usr/local/share/nems/nems-scripts/inc/terminal-colors.php');
$colors = new Colors();

$ver = $argv[1];
$confsrc = $argv[2];
$confdest = $argv[3];

  // This script is used to reconcile the settings for default NEMS Nagios configs with your NEMS-Migrator backup.
  // We'll take care of the commands / services / hosts configs, but will leave users as is so we don't clobber the nems-init account data

  echo PHP_EOL . "Creating Nagios Core config files:" . PHP_EOL;

  $files = array(
    array('file'=>'Default_collector/advanced_services.cfg','unique'=>'service_description'),
    array('file'=>'Default_collector/hostgroups.cfg','unique'=>'hostgroup_name'),
    array('file'=>'Default_collector/hosts.cfg','unique'=>'host_name'),
    array('file'=>'Default_collector/servicegroups.cfg','unique'=>'servicegroup_name'),
    array('file'=>'Default_collector/services.cfg','unique'=>'service_description'),
    array('file'=>'global/checkcommands.cfg','unique'=>'command_name'),
    array('file'=>'global/host_templates.cfg','unique'=>'name'),
    array('file'=>'global/misccommands.cfg','unique'=>'command_name'),
    array('file'=>'global/service_templates.cfg','unique'=>'name'),
  );

  if ($ver >= 1.5) {
    // NEMS 1.5 introduces more support for migration
    $files2 = array(
# -need to add one for the unique id      array('file'=>'Default_collector/host_dependencies.cfg','unique'=>'name'),
# -need to add one for the unique id      array('file'=>'Default_collector/service_dependencies.cfg','unique'=>'name'),
      array('file'=>'global/contactgroups.cfg','unique'=>'contactgroup_name'),
      array('file'=>'global/timeperiods.cfg','unique'=>'timeperiod_name'),
    );
    $files = array_merge($files,$files2);
  }

  echo 'Reconciling ' . count($files) . ' files.' . PHP_EOL;

  foreach ($files as $file) {
    $backup = '/tmp/nems_migrator_restore' . $confsrc . '/' . $file['file'];
    if ($ver >= 1.6) {
      $default = '/root/nems/nems-migrator/data/nagios/conf/' . $file['file'];
    } else if ($ver >= 1.5) {
      $default = '/root/nems/nems-migrator/data/1.5/nconf/confdump/' . $file['file'];
    } else if ($ver >= 1.4) {
      $default = '/root/nems/nems-migrator/data/1.4/nagios/conf/' . $file['file'];
    } else {
      $default = '/root/nems/nems-migrator/data/nagios/conf/' . $file['file'];
    }
    $dest = $confdest . '/' . $file['file'];

    $data = new stdClass();
    $data->backup = parsefile($backup,$file);
    $data->default = parsefile($default,$file);

    if (isset($data->backup) && isset($data->default)) {
      $consolidation = array();
      # Load the defaults
      foreach ($data->default as $definition) {
        $consolidation[$definition['name']] = $definition['data'];
      }
      # Now overwrite defaults with NEMS-Migrator backup
      foreach ($data->backup as $definition) {
        if ($file['file'] == 'Default_collector/services.cfg' && isset($consolidation[$definition['name']])) {
          if (!isset($counter[$definition['name']])) $counter[$definition['name']] = 2; else $counter[$definition['name']] = $counter[$definition['name']]++;
          $definition['name'] = $definition['name'] . ' - ' . $counter[$definition['name']];
        }
        $consolidation[$definition['name']] = $definition['data'];
      }
      $newfile = '# ' . $file['file'] . PHP_EOL . '# This file was generated by NEMS-Migrator' . PHP_EOL . '# Visit https://nemslinux.com/ to learn more' . PHP_EOL . PHP_EOL;
      $newfileEND = '';

      foreach ($consolidation as $definition) {
        $isChild = 0;
        // Check if it has a parent
        foreach ($definition as $index=>$line) {
          if (strtolower(substr(trim($line),0,6)) == 'parent') {
            $isChild = 1;
          }
        }
        foreach ($definition as $index=>$line) {
          if ($isChild == 1) {
            // This is a child host, so we need to make sure it ends up at the very end of the output file
            $newfileEND .= '          ';
            if ($index != 0 && $index != key( array_slice( $definition, -1, 1, TRUE ) ) ) $newfileEND .= '          '; // some basic indentation
            $newfileEND .= $line . PHP_EOL;
          } else {
            $newfile .= '          ';
            if ($index != 0 && $index != key( array_slice( $definition, -1, 1, TRUE ) ) ) $newfile .= '          '; // some basic indentation
            $newfile .= $line . PHP_EOL;
          }
        }
        $newfile .= PHP_EOL;
      }
      $newfile .= $newfileEND; // MERGE the parent and child data

      // clobber the original file
      if ($file['file'] == 'Default_collector/advanced_services.cfg') {
        # advanced_services cfg can't have services that are not associated with hosts. Therefore we need two copies: 1 for NConf and one for Nagios
        copy($backup,$dest); # the exact duplicate of the backup
	file_put_contents('/tmp/reconcile-advanced-services.cfg',$newfile);
      } else {
        file_put_contents($dest,$newfile);
      }
    }

  }


    echo 'Consolidation complete.' . PHP_EOL;

  echo PHP_EOL;

    function parsefile($filename,$file) {
      global $colors;
      $definitions = array(); // prevent error if file is empty
      if (substr($filename,0,5) == '/tmp/') $filename_short = 'your backup of ';
      if (substr($filename,0,6) == '/root/') $filename_short = 'NEMS\' Default of ';
      $filename_short .= basename($filename);
      echo 'Scanning ' . $colors->getColoredString($filename_short, "light_gray", "black") . '... ';
      if (!file_exists($filename)) {
        echo $colors->getColoredString("File not found. Cannot load.", 'red', 'black') . PHP_EOL;
      } else {
        echo $colors->getColoredString("File found.", 'green', 'black') . ' ';
	$data = file($filename);
        if (is_array($data) && count($data) > 0) {
          echo 'Importing ' . count($data) . ' lines.';
      $inside = 0;
      $index = 0;

      foreach ($data as $line) {

        $line = trim($line);

        if (substr($line,0,6) == 'define') {
          $inside = 1;
        }

        if ($inside == 1 && substr($line,0,strlen($file['unique'])) == $file['unique']) {
          $name = trim( substr( $line,strlen($file['unique']) ) );
          $definitions[$index]['name'] = $name;
        }


        if ($inside == 1) $definitions[$index]['data'][] = $line;

        if (substr($line,0,1) == '}') {
          $inside = 0;
          $index++;
        }

      }
      } else {
        echo $colors->getColoredString("Couldn't find any data. Aborting.", 'red', 'black');
      }
      echo PHP_EOL;
      }
      return $definitions;
    }


?>
