# 20_baseurls.pl - Constructs base URLs for EPrints (HTTPS-only)

{
    my $uri = URI->new("https://");

    # Ensure securehost is set for HTTPS-only configuration
    unless (EPrints::Utils::is_set($c->{securehost})) {
        die "securehost is not set! This repository is configured to be HTTPS-only.";
    }

    # Set up the URI for HTTPS
    $uri->scheme("https");
    $uri->host($c->{securehost});
    $uri->port($c->{secureport} || 443);  # Default to port 443 if not set
    $uri = $uri->canonical;

    # Ensure the path does not start or end with a slash
    my $path = $c->{https_root} || "";
    $path =~ s{^/|/$}{}g;  # Remove leading and trailing slashes
    $uri->path($path);

    # EPrints base URL without trailing slash
    $c->{base_url} = "$uri";
    # CGI base URL without trailing slash
    $c->{perl_url} = "$uri/cgi";
	
	    ### DEBUG OUTPUT ###
#    use Data::Dumper;
#    local $Data::Dumper::Indent = 1;  # Compact output
#    print "\n--- Final Variable Values ---\n";
#    print "URI: " . $uri->as_string . "\n";
#    print "Path: " . ($path || "(empty)") . "\n";
#    print "\$c->{base_url}: " . ($c->{base_url} || "(unset)") . "\n";
#    print "\$c->{perl_url}: " . ($c->{perl_url} || "(unset)") . "\n";
#    print "\nFull \$c dump (relevant parts):\n";
#    print Dumper({
#        securehost => $c->{securehost},
#        secureport => $c->{secureport} // '(default 443)',
#        https_root => $c->{https_root} // '(unset)',
#        base_url   => $c->{base_url},
#        perl_url   => $c->{perl_url},
#    });
#    print "--- End Debug ---\n\n";
#	
}

# Set EPrints abstract page URL to /id/eprint/XX instead of the shorter version /XX, for search engine optimisation.
$c->{use_long_url_format} = 1;

# written with the help of DeekSeek based on the file that was shipped.
