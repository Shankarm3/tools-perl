#!/usr/bin/perl
use strict;
use warnings;
use Text::Unidecode;

die "Usage: $0 <xml_file> <bibcit_id>\n" unless @ARGV == 2;
my ($xml_file, $bibcit_id) = @ARGV;

open my $fh, '<:encoding(UTF-8)', $xml_file or die "Cannot open $xml_file: $!";
local $/;
my $xml = <$fh>;
$xml = unidecode($xml);   
$xml =~ s/\&amp;/\&/g;
close $fh;

$xml =~ s/\xA0/ /g;

my $bibcit_pattern = qr{
    <bibcit\b
    [^>]*?
    rid\s*=\s*["']\Q$bibcit_id\E["']
    [^>]*?>
    .*?
    <\/bibcit>
}xis;

# Author(s) pattern: allows multiple names, commas, ampersands, "et al."
my $author_pattern = qr{
    [A-Z][a-zA-Z\-\']+ 
    (?:        
        (?:,\s*[A-Z][a-zA-Z\-\']+)* 
        (?:\s*&\s*[A-Z][a-zA-Z\-\']+)?
    )?
    (?:\s+et\s*al\.)?
    \s*
}x;

my @patterns = (
    qr{ \(\s* $author_pattern $bibcit_pattern \s* \) }xis,
    qr{ $author_pattern \(\s* $bibcit_pattern \s* \) }xis,
    qr{ $author_pattern $bibcit_pattern }xis,             
);

my %found;
my $xml_copy = $xml;

for my $pat (@patterns) {
    while ($xml_copy =~ /$pat/g) {
        my $match = $&;
        $match =~ s/^\s+|\s+$//g;
        $found{$match} = 1;
        $xml_copy =~ s/\Q$match\E//;
        pos($xml_copy) = 0;
    }
}


if (%found) {
    print "Found patterns for bibcit id '$bibcit_id':\n";
    print "$_\n" for sort keys %found;
} else {
    print "No patterns found for bibcit id '$bibcit_id'.\n";
}