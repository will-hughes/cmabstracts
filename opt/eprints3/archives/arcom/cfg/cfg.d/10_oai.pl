package EPrints::arcom;

# Disable OAI completely since this is a metadata catalogue
$c->{oai}->{enable} = 0;

1;
