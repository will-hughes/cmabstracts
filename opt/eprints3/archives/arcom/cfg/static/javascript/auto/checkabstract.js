/* Check your own abstract (/cgi/checkabstract)
   Place in /opt/eprints3/archives/arcom/cfg/static/javascript/auto/
   Counts the ticked keyword terms and copies them. Runs only in the browser;
   nothing is sent anywhere. */

document.addEventListener( 'DOMContentLoaded', function() {
	var box = document.getElementById( 'chk_keywords' );
	if( !box ) { return; }
	var status = document.getElementById( 'chk_kw_status' );
	var copy = document.getElementById( 'chk_kw_copy' );

	function ticked() {
		return Array.prototype.slice.call( box.querySelectorAll( 'input[type=checkbox]:checked' ) );
	}

	function update() {
		var t = ticked();
		var facets = {};
		t.forEach( function( c ) { facets[ c.getAttribute( 'data-facet' ) ] = 1; } );
		var nf = Object.keys( facets ).length;
		status.textContent = t.length + ( t.length === 1 ? ' term' : ' terms' ) +
			' ticked, covering ' + nf + ' of 5 facets.';
	}

	box.addEventListener( 'change', update );
	update();

	copy.addEventListener( 'click', function() {
		var text = ticked().map( function( c ) { return c.value; } ).join( '; ' );
		if( text === '' ) { return; }
		if( navigator.clipboard ) {
			navigator.clipboard.writeText( text ).then( function() {
				status.textContent = 'Copied: ' + text;
			} );
		}
	} );
} );
