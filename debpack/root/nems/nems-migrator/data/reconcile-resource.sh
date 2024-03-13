#!/usr/bin/php
<?php
# This script is used to consolidate settings in config files.
# For example, as NEMS evolves, config settings in the resource.cfg file may be added.
# Traditional "replacement" of the config file would result in those new settings missing.
# So this script consolidates the data between the source (backup.nems) and destination (resource.cfg).

echo "Reconciling Nagios resource.cfg against backup... " . PHP_EOL;

$resourcesrc = $argv[1];
$resourcedest = $argv[2];

$source = '/tmp/nems_migrator_restore' . $resourcesrc . '/resource.cfg';
$dest   = $resourcedest . '/resource.cfg';

// Load source file contents
$sourceContent = file_get_contents($source);
if ($sourceContent === false) {
    echo 'ERROR: Failed to read source file.' . PHP_EOL;
    exit(1);
}

// Load destination file contents
$destContent = file_get_contents($dest);
if ($destContent === false) {
    echo 'ERROR: Failed to read destination file.' . PHP_EOL;
    exit(1);
}

// Define the new header
$newHeader = <<<HEADER
###########################################################################
#
# RESOURCE.CFG - Resource File for Nagios
#
# This file is configured using the NEMS System Settings Tool
# Please do not edit it directly.
#
###########################################################################
HEADER;

// Check if the new header is already present in the destination file
if (strpos($destContent, $newHeader) === false) {
    // Replace the header in the destination file
    $destContent = preg_replace('/^#{2,}.*?(?=^#{2,}|\z)/ms', $newHeader . PHP_EOL, $destContent, 1);
}

// Consolidate settings from source to destination
foreach (explode(PHP_EOL, $sourceContent) as $line) {
    $line = trim($line);
//    echo '  Importing: ' . $line . PHP_EOL;
    if (substr($line, 0, 1) == '$') {
        $parts = explode('=', $line, 2);
        $variable = trim(substr($parts[0], 1));
        echo '  Importing $' . $variable . PHP_EOL;
        $value = isset($parts[1]) ? trim($parts[1]) : '';

        // Check if the variable already exists in destination content
        $existingLine = '$' . $variable . '=';

        if (strpos($destContent, $existingLine) !== false) {
            // Variable exists, replace its value
            $destContent = preg_replace('/\$' . preg_quote($variable, '/') . '=.*/', '$' . $variable . '=' . $value, $destContent);
        } else {
            // Variable does not exist, add it to the destination content
            $destContent .= '$' . $variable . '=' . $value . PHP_EOL;
        }
    }
}

// Write updated content to destination file
if (file_put_contents($dest, $destContent) === false) {
    echo 'ERROR: Failed to write to destination file.' . PHP_EOL;
    exit(1);
}

echo 'Consolidation complete.' . PHP_EOL;
