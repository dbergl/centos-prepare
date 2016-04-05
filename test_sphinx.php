<?php

$external_ip = trim(`ip -4 a | grep inet | grep -v '127\.0\.0\.1' | awk '{print $2;}' | cut -d'/' -f1`);

$connections = [
    [ 'server' => '/var/run/sphinx/sphinx.sock', 'port' => 3312 ],
    [ 'server' => '127.0.0.1', 'port' => 3312 ],
    [ 'server' => 'localhost', 'port' => 3312 ],
    [ 'server' => $external_ip, 'port' => 3312 ],
];

foreach ($connections as $c) {
	$sphinx = new SphinxClient();
	$sphinx->setServer($c['server'], $c['port']);
	$sphinx->setLimits(0, 1000, 1000, 0);
	$sphinx->setMatchMode(SPH_MATCH_EXTENDED);
	$nid = $sphinx->addQuery('ford', 'natural natural_d');
	$bid = $sphinx->addQuery('ford', 'bulk bulk_d');
	$qr  = $sphinx->runQueries();
	$le  = $sphinx->getLastError();

	echo '<pre>';
	if ($le) {
	    echo $c['server'] . ': ' . $le . "\n";
	} else {
	    echo $c['server'] . ": {$qr[$nid]['total_found']} natural found in {$qr[$nid]['time']} secs.\n";
	    echo $c['server'] . ": {$qr[$bid]['total_found']} bulk found in {$qr[$bid]['time']} secs.\n";
	}
	echo '</pre>';
}


