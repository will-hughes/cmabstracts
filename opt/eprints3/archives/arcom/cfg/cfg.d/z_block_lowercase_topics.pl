# Refuse /view/topic/ URLs whose first letter is lowercase.
# Topic ids are assigned by EPrints and always begin with a capital.
# Lowercase variants (from an external scraper, first seen ~9 Sep 2026)
# miss the static view cache but still match the record set, so Apache
# built full multi-MB topic pages in-process, causing the OOM kills of
# 11 Sep 2026. This trigger runs before EPrints::Update::Views builds
# anything (Rewrite.pm: trigger at l.173, return at l.191, views at l.848).
# The index page is exempt because its name starts lowercase.
$c->add_trigger( EP_TRIGGER_URL_REWRITE, sub {
	my( %o ) = @_;
	if( $o{uri} =~ m{^/view/topic/(?!index\.)[a-z]} )
	{
		${$o{return_code}} = 404;
		return EP_TRIGGER_DONE;
	}
	return;
});