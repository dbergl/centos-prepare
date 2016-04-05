<?php

    require 'HTMLPurifier.includes.php';

    $orig = "<h1>Hello World</h1><p>How are you all?</p><script src=\"http://ya.da/s.js\"></script>";

    $config = HTMLPurifier_Config::createDefault();
    $config->set('HTML.Doctype', 'HTML 4.01 Strict');
    $config->set('HTML.Nofollow', true);
    $config->set('HTML.Proprietary', true);
    $config->set('HTML.SafeEmbed', true);
    $config->set('HTML.SafeObject', true);
    $config->set('Output.FlashCompat', true);
    $config->set('AutoFormat.Linkify', true);
    $config->set('CSS.Proprietary', true);
    $def = $config->getHTMLDefinition(true);
    $def->addAttribute('a', 'data-link', 'Text');
    $purifier = new HTMLPurifier($config);
    $out = $purifier->purify($orig);

    echo $out;


