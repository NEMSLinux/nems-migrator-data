#!/usr/bin/php
<?php

echo "Consolidating NEMS SST configuration:" . PHP_EOL;

// Define the filenames for the current and backup configuration files
$currentFile = '/usr/local/share/nems/nems.conf';
$backupFile = $argv[1];

// Load contents of the current and backup configuration files
$currentLines = file($currentFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$backupLines = file($backupFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

// Parse lines into key-value pairs for the current configuration
$currentConfig = [];
foreach ($currentLines as $line) {
    list($key, $value) = explode('=', $line, 2) + [null, null]; // Using list() to extract key and value
    if ($key !== null && $value !== null) {
        $currentConfig[trim($key)] = trim($value);
    }
}

// Parse lines into key-value pairs for the backup configuration
$backupConfig = [];
foreach ($backupLines as $line) {
    list($key, $value) = explode('=', $line, 2) + [null, null]; // Using list() to extract key and value
    if ($key !== null && $value !== null) {
        $backupConfig[trim($key)] = trim($value);
    }
}

// Define keys that should be preserved from the current configuration
$preserveKeys = ['version', 'apikey', 'nemsuser'];

// Check for empty values for keys we would rather pull from current configuration. Use backup if empty in current.
if (empty($currentConfig['alias'])) {
    $currentConfig['alias'] = isset($backupConfig['alias']) ? $backupConfig['alias'] : '';
}

// Iterate through each entry in the backup configuration
foreach ($backupConfig as $key => $value) {
    // Check if the key exists in the current configuration and should be preserved
    if (in_array($key, $preserveKeys) || ($key == 'nemsuser' && isset($currentConfig['nemsuser'])) || ($key == 'alias' && isset($currentConfig['alias']))) {
        // Preserve the value from the current configuration
        $backupConfig[$key] = isset($currentConfig[$key]) ? $currentConfig[$key] : $value;
    }
}

// Write the updated backup configuration to the backup file
$backupContent = '';
foreach ($backupConfig as $key => $value) {
    $backupContent .= "$key=$value" . PHP_EOL;
    echo "Importing: \033[97m" . $key . "\033[0m" . PHP_EOL;
}
file_put_contents($currentFile, $backupContent);

echo "Consolidation complete." . PHP_EOL . PHP_EOL;
