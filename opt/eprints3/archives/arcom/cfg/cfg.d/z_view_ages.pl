# Never let an Apache worker regenerate a browse view on demand.
# The nightly generate_views_and_reload.sh cron rebuilds all views; with the
# EPrints default (lists older than 1 day are rebuilt on request), a failed
# nightly run made crawler hits trigger heavy rebuilds inside Apache, causing
# the stuck worker of 24 Oct and the OOM outage of 26 Oct 2026.
foreach my $view ( @{ $c->{browse_views} } )
{
	$view->{max_menu_age} = 10*24*60*60;  # 10 days
	$view->{max_list_age} = 10*24*60*60;  # 10 days
}
