# This file was edited from that created by bin/epadmin
# You can regenerate this file by doing ./bin/epadmin config_core arcom but it will overwrite these settings

# 2026-08-22: domain changed from arcomabstracts.com to cmabstracts.com
# (separation from ARCOM). Old hostnames redirect at Cloudflare.

 $c->{host} = 'cmabstracts.com'; 
 $c->{base_url} = 'https://cmabstracts.com';
 $c->{perl_url} = 'https://cmabstracts.com/cgi';
 $c->{https_cgiurl} = 'https://cmabstracts.com/cgi';
 
$c->{securehost} = $c->{host};
$c->{secureport} = 443;
$c->{port} = 443;
$c->{protocol} = 'https';
$c->{http_root} = undef;

$c->{aliases} = []; # this feeds vhost generation ONLY, this install hand-maintains securevhost.conf and re-directs are handled at Cloudflare
$c->{urlpath} = "/";
$c->{userhome} = "/cgi/users/home";