#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

my $input_file = 'staf323.xml';
# my $input_file = 'EJ001.xml';
my $output_file = 'extracted_citations.txt';

open(my $in_fh, '<', $input_file) or die "Could not open input file '$input_file': $!\n";
my $content = do { local $/; <$in_fh> };
close $in_fh;

open(my $out_fh, '>', $output_file) or die "Could not open output file '$output_file': $!\n";

print "Extracting citations from: $input_file\n";
print "Saving to: $output_file\n";
my %citations;

# Your existing pattern
my $pat1 = qr{
    \(              
    [^(]*?
    <bibcit\b[^>]*>  
    \d{4}            
    </bibcit>        
    [^)]*            
    \)
}x;

# New patterns
my $pat3 = qr{
    ([A-Z][a-z]+)\s*
    <bibcit\b[^>]*>(\d{4})<\/bibcit>
}xi;

# Update pattern2 to handle the specific case
my $pat4 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;

my $pat5 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+\s*&\s*[A-Z][a-z]+) 
    \s*\(\s*                                          
    <bibcit\b[^>]*>(\d{4})<\/bibcit>                  
    \s*\)+                                            
}xi;

my $pat6 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*;\s*                                   
    \s*<bibcit\b[^>]*>\d+<\/bibcit>           
    \s*\)                                     
}xi;

my $pat7 = qr{
    ([A-Z][a-z]+)                              
    \s+<[^>]+>et\s*al\.<\/[^>]+>              
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;

# Add this new pattern specifically for the format you mentioned
my $pat2 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;

# Array of all patterns to check
my @all_patterns = (
    $pat2,  # Add the new specific pattern first
    $pat1,
    $pat3,
    $pat4,
    $pat5,
    $pat6,
    $pat7
);
# Process all patterns
my %seen;
foreach my $pattern (@all_patterns) {
    while ($content =~ /$pattern/g) {
        my $full_match = $&;
        next if $seen{$full_match}++;  # Skip if we've already seen this exact match
        
        my $year;
        if ($pattern == $pat1) {
            $year = ($full_match =~ /<bibcit[^>]*>(\d{4})/)[0];
        } else {
            $year = $+;  # Get the last captured group (the year)
        }
        
        $citations{$full_match} = $year;
        $content =~ s/\Q$full_match\E//;
    }
}
print $out_fh "EXTRACTED CITATIONS\n";
print $out_fh "=" x 50 . "\n\n";
my $count = 1;

foreach my $citation (sort { 
    ($citations{$a} || 0) <=> ($citations{$b} || 0) || 
    $a cmp $b 
} keys %citations) {
    my $clean_citation = $citation;
    $clean_citation =~ s/<[^>]+>//g;
    $clean_citation =~ s/\s+/ /g;
    $clean_citation =~ s/\s+\)/)/g;
    $clean_citation =~ s/\(\s+/(/g;
    print("$citation ======> $citations{$citation}\n");
    
    print $out_fh sprintf("ID ====> %-4d Citation=====>%s Clened======>%s\n\n", 
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