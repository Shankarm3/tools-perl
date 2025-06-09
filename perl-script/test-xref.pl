#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

my $input_file = 'staf323_Source.xml';
# my $input_file = 'EJ001.xml';
my $output_file = 'extracted_citations.txt';

open(my $in_fh, '<', $input_file) or die "Could not open input file '$input_file': $!\n";
my $content = do { local $/; <$in_fh> };
close $in_fh;

open(my $out_fh, '>', $output_file) or die "Could not open output file '$output_file': $!\n";

print "Extracting citations from: $input_file\n";
print "Saving to: $output_file\n";
my %citations;

while ($content =~ /(\([^<]+?<xref\s+[^>]*>(\d{4})<\/xref>[^)]*\))/g) {
    my $full_match = $1;
    my $year = $2;
    $citations{$full_match} = $year;
}

while ($content =~ /([A-Z][a-z]+(?:,\s+[A-Z][a-z.]+)*)\s*\(\s*(<xref[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/xref>)\s*\)/g) {
    my $author = $1;
    my $year = $2;
    my $citation = "$author ($year)";
    $citations{$citation} = $year;
}

while ($content =~ /(\([^<]+?et al\.\s*,\s*(<xref[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/xref>)[^)]*\))/g) {
    my $full_match = $1;
    my $year = $2;
    $citations{$full_match} = $year;
}

while ($content =~ /([A-Z][a-z]+(?:,\s+[A-Z][a-z.]+)*)\s*\(\s*(<xref[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/xref>)\s*\)/g) {
    my $author = $1;
    my $year = $2;
    my $citation = "$author ($year)";
    $citations{$citation} = $year;
}

while ($content =~ /(\(\s*([A-Z][a-z]+(?:,\s+[A-Z][a-z.]+)*\s+<xref[^>]*ref-type="bibr"\s+[^>]*>(\d{4})<\/xref>\s*)\))/g) {
    my $full_match = $1;
    my $year = $2;
    $citations{$full_match} = $year;
}

print $out_fh "EXTRACTED CITATIONS\n";
print $out_fh "=" x 50 . "\n\n";
my $count = 1;

foreach my $citation (sort { 
    ($citations{$a} || 0) <=> ($citations{$b} || 0) || 
    $a cmp $b 
} keys %citations) {
    print("$citation ======> $citations{$citation}\n");
    my $clean_citation = $citation;
    $clean_citation =~ s/<[^>]+>//g;
    $clean_citation =~ s/\s+/ /g;
    $clean_citation =~ s/\s+\)/)/g;
    $clean_citation =~ s/\(\s+/(/g;
    
    print $out_fh sprintf("%-4d %s %s\n", 
        $count++,
        $citation,
        $clean_citation
    );
}

print $out_fh "\n" . "=" x 50 . "\n";
print $out_fh "Total unique citations found: " . scalar(keys %citations) . "\n";

close $out_fh;

print "\nExtraction complete. Found " . scalar(keys %citations) . " unique citations.\n";
print "Results saved to: $output_file\n";