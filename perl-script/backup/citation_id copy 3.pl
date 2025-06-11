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

# Author(s) pattern
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

my $xml_copy = $xml;
my %full_match_count;
my %pattern_type_count;
my %pattern_type_matches;

for my $pat (@patterns) {
    while ($xml_copy =~ /$pat/g) {
        my $match = $&;
        $match =~ s/^\s+|\s+$//g;
        $full_match_count{$match}++;
        my $type;
        if ($match =~ /^\(.*<bibcit.*<\/bibcit>\)$/) {
            $type = 'parens';
        } elsif ($match =~ /^[^()]*\(<bibcit.*<\/bibcit>\)$/) {
            $type = 'author_parens';
        } elsif ($match =~ /^[^()]*<bibcit.*<\/bibcit>$/) {
            $type = 'no_parens';
        } else {
            $type = 'other';
        }
        $pattern_type_count{$type}++;
        push @{$pattern_type_matches{$type}}, $match;
        $xml_copy =~ s/\Q$match\E//;
        pos($xml_copy) = 0;
    }
}

# Find the most common pattern type
my ($most_common_type) = sort { $pattern_type_count{$b} <=> $pattern_type_count{$a} } keys %pattern_type_count;

# Print all matched patterns
if (%full_match_count) {
    print "All matched patterns for bibcit id '$bibcit_id':\n";
    for my $m (sort keys %full_match_count) {
        print "$m\n";
    }
    # print "\nMost common pattern type: $most_common_type\n";
}

# Print all matches from the most common pattern type
if ($most_common_type && @{$pattern_type_matches{$most_common_type}}) {
    my @sorted = sort @{$pattern_type_matches{$most_common_type}};
    # print "$sorted[0]\n";
} else {
    print "No patterns found for bibcit id '$bibcit_id'.\n";
}