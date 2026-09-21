use strict;

# Enable the Bulk Import plugin only for staff
$c->{plugins}->{'Import::Bulk'}->{params}->{visible} = "staff";


# Generic Plugin Options

# To disable the plugin "Export::BibTeX":
# $c->{plugins}->{"Export::BibTeX"}->{params}->{disable} = 1;

# To enable the plugin "Export::LocalThing":
# $c->{plugins}->{"Export::LocalThing"}->{params}->{disable} = 0;

# Screen Plugin Configuration
# (Disabling a screen will also remove it and it's actions from all lists)

# To add the screen Screen::Items to the key_tools list at position 200:
# $c->{plugins}->{"Screen::Items"}->{appears}->{key_tools} = 200;

# To remove the screen Screen::Items from the key_tools list:
# $c->{plugins}->{"Screen::Items"}->{appears}->{key_tools} = undef;


# Disabling Issues plugins so that my local ones do not overlap
$c->{plugins}->{"Issues::SimilarTitles"}->{params}->{disable} = 1;
$c->{plugins}->{"Issues::ExactTitleDups"}->{params}->{disable} = 1;


# Screen Actions Configuration

# To disable action "blah" of Screen::Items 
# (Disabling an action will also remove it from all lists)
# $c->{plugins}->{"Screen::Items"}->{actions}->{blah}->{disable} = 1;

# To add action "blah" of Screen::Items to the key_tools list at position 200: 
# $c->{plugins}->{"Screen::Items"}->{actions}->{blah}->{appears}->{key_tools} = 200;

# To remove action "blah" of Screen::Items from the key_tools list
# $c->{plugins}->{"Screen::Items"}->{actions}->{blah}->{appears}->{key_tools} = undef;


# Import/export plugins

# to make a plugin only available to staff
# $c->{plugins}->{"Export::Text"}->{params}->{visible} = "staff";

# to only command line tools
# $c->{plugins}->{"Export::Text"}->{params}->{visible} = "api";

# to prevent a import/export plugin from being shown as an option, but
# not actually disable it.
# $c->{plugins}->{"Export::BibTeX"}->{params}->{advertise} = 0;

# Only show selected export plugins to regular users
$c->{plugins}{"Export::MyPlugins::RIS"}{params}{visible} = "all";
$c->{plugins}{"Export::arcomCSV"}{params}{visible} = "staff";
$c->{plugins}{"Export::MyPlugins::EndNote"}{params}{visible} = "all";    # ← FIXED
$c->{plugins}{"Export::MyPlugins::BibTeX"}{params}{visible} = "all";     # ← FIXED
$c->{plugins}{"Export::HTML"}{params}{visible} = "all";
$c->{plugins}{"Export::HTML"}{params}{disable} = 0;  # Explicitly enable

# Disable conflicting standard/flavour plugins
$c->{plugins}{"Import::RIS"}{params}{disable} = 0;
$c->{plugins}{"Export::RIS"}{params}{disable} = 1;
$c->{plugins}{"Import::EndNote"}{params}{disable} = 1;
$c->{plugins}{"Export::EndNote"}{params}{disable} = 1;
$c->{plugins}{"Export::BibTeX"}{params}{disable} = 1;

# Handle case sensitivity - redirect lowercase to proper case
$c->{plugin_alias_map}->{"Export::myplugins::ris"} = "Export::MyPlugins::RIS";
$c->{plugin_alias_map}->{"Export::myplugins::endnote"} = "Export::MyPlugins::EndNote";
$c->{plugin_alias_map}->{"Export::myplugins::bibtex"} = "Export::MyPlugins::BibTeX";
$c->{plugin_alias_map}->{"Export::bibtex"} = "Export::MyPlugins::BibTeX";
$c->{plugin_alias_map}->{"Export::Bibtex"} = "Export::MyPlugins::BibTeX";
$c->{plugin_alias_map}->{"Export::html"} = "Export::HTML";

# Hide all others from regular users
$c->{plugins}{"Export::Atom"}{params}{visible} = "staff";
$c->{plugins}{"Export::BadData"}{params}{visible} = "staff";
$c->{plugins}{"Export::BatchEdit"}{params}{visible} = "staff";
$c->{plugins}{"Export::COinS"}{params}{visible} = "staff";
$c->{plugins}{"Export::CSV"}{params}{visible} = "none";
$c->{plugins}{"Export::CerifXML"}{params}{visible} = "none";
$c->{plugins}{"Export::ContextObject"}{params}{visible} = "none";
$c->{plugins}{"Export::ContextObject::Book"}{params}{visible} = "none";
$c->{plugins}{"Export::ContextObject::Dissertation"}{params}{visible} = "none";
$c->{plugins}{"Export::ContextObject::DublinCore"}{params}{visible} = "none";
$c->{plugins}{"Export::ContextObject::Journal"}{params}{visible} = "none";
$c->{plugins}{"Export::DC"}{params}{visible} = "staff";
$c->{plugins}{"Export::DIDL"}{params}{visible} = "staff";
$c->{plugins}{"Export::GScholar"}{params}{visible} = "staff";
$c->{plugins}{"Export::Grid"}{params}{visible} = "staff";
$c->{plugins}{"Export::Ids"}{params}{visible} = "staff";
$c->{plugins}{"Export::JSON"}{params}{visible} = "none";
$c->{plugins}{"Export::METS"}{params}{visible} = "none";
$c->{plugins}{"Export::MODS"}{params}{visible} = "staff";
$c->{plugins}{"Export::MultilineCSV"}{params}{visible} = "none";
$c->{plugins}{"Export::OAI_Bibliography"}{params}{visible} = "none";
$c->{plugins}{"Export::OAI_DC"}{params}{visible} = "none";
$c->{plugins}{"Export::OAI_UKETD_DC"}{params}{visible} = "none";
$c->{plugins}{"Export::OldXML"}{params}{visible} = "none";
$c->{plugins}{"Export::RDFN3"}{params}{visible} = "none";
$c->{plugins}{"Export::RDFNT"}{params}{visible} = "none";
$c->{plugins}{"Export::RDFXML"}{params}{visible} = "none";
$c->{plugins}{"Export::RIS"}{params}{visible} = "none";  # Hide default RIS
$c->{plugins}{"Export::RSS"}{params}{visible} = "staff";
$c->{plugins}{"Export::RSS2"}{params}{visible} = "staff";
$c->{plugins}{"Export::Refer"}{params}{visible} = "staff";
$c->{plugins}{"Export::Simple"}{params}{visible} = "staff";
$c->{plugins}{"Export::StaffXML"}{params}{visible} = "none";
$c->{plugins}{"Export::Text"}{params}{visible} = "staff";
$c->{plugins}{"Export::XML"}{params}{visible} = "none";
$c->{plugins}{"Export::XMLFiles"}{params}{visible} = "none";



# Plugin Mapping

# The following would make the repository use the LocalDC export plugin
# anytime anything asks for the DC plugin - this is a handy way to override
# the behaviour without hacking the existing plugin. 
# $c->{plugin_alias_map}->{"Export::DC"} = "Export::LocalDC";
# This line just means that the LocalDC plugin doesn't appear in addition
# as that would be confusing. 
# $c->{plugin_alias_map}->{"Export::LocalDC"} = undef;
        
# CrossRef registration
$c->{plugins}->{"Import::DOI"}->{params}->{disable} = 1;

# You should replace this with your own CrossRef account username and password.

#$c->{plugins}->{"Import::DOI"}->{params}->{pid} = "ourl_eprintsorg:eprintsorg";
# set the default options for the DOI import plugin - change these to reflect your
# own repository requirements
#$c->{plugins}->{"Import::DOI"}->{params}->{doi_field} = "id_number";
#$c->{plugins}->{"Import::DOI"}->{params}->{use_prefix} = 1;


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2022 University of Southampton.
EPrints 3.4 is supplied by EPrints Services.

http://www.eprints.org/eprints-3.4/

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints 3.4 L<http://www.eprints.org/>.

EPrints 3.4 and this file are released under the terms of the
GNU Lesser General Public License version 3 as published by
the Free Software Foundation unless otherwise stated.

EPrints 3.4 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints 3.4.
If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

