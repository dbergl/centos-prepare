<?php

$external_ip = trim(`ip -4 a | grep inet | grep -v '127\.0\.0\.1' | awk '{print $2;}' | cut -d'/' -f1`);

$connections = [
    [ 'server' => '127.0.0.1', 'port' => 6379 ],
    [ 'server' => 'localhost', 'port' => 6379 ],
    [ 'server' => $external_ip, 'port' => 6379 ],
    [ 'server' => '/var/run/redis/redis.sock' ],
];

foreach ($connections as $c) {

    $redis = new Redis();
    if (isset($c['port'])) {
        $conn = $redis->connect($c['server'], $c['port']);
    } else {
        $conn = $redis->connect($c['server']);
    }

    echo '<pre>';
    if (!$conn) {
        echo "Redis ({$c['server']}): connection failed.\n";
    } else {
        echo "Redis ({$c['server']}): connected!\n";
    }

    $orig = 'hello';
    $redis->set('somekey', $orig);
    $out = $redis->get('somekey');
    if ($orig == $out) {
        echo "  set/get: succeeded!\n";
    }
    echo '</pre>';
}

