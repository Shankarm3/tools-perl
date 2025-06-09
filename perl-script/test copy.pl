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

my $existing_pattern = qr{
    \(              
    [A-Za-z][^<]*?  # Require at least one word character (author name)
    <bibcit\b[^>]*>  
    \d{4}            
    </bibcit>        
    [^)]*            
    \)
}x;

# New patterns
my $pattern1 = qr{
    ([A-Z][a-z]+)\s*
    <bibcit\b[^>]*>(\d{4})<\/bibcit>
}xi;

# Update pattern2 to handle the specific case
my $pattern2 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;

my $pattern3 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+\s*&\s*[A-Z][a-z]+) 
    \s*\(\s*                                          
    <bibcit\b[^>]*>(\d{4})<\/bibcit>                  
    \s*\)+                                            
}xi;

my $pattern4 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*;\s*                                   
    \s*<bibcit\b[^>]*>\d+<\/bibcit>           
    \s*\)                                     
}xi;

my $pattern5 = qr{
    ([A-Z][a-z]+)                              
    \s+<[^>]+>et\s*al\.<\/[^>]+>              
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;

# Add this new pattern specifically for the format you mentioned
my $pattern6 = qr{
    ([A-Z][a-z]+,\s+[A-Z][a-z]+)             
    \s*\(\s*                                  
    <bibcit\b[^>]*>(\d{4})<\/bibcit>          
    \s*\)                                     
}xi;

# Array of all patterns to check
my @all_patterns = (
    $pattern6,  # Add the new specific pattern first
    $existing_pattern,
    $pattern1,
    $pattern2,
    $pattern3,
    $pattern4,
    $pattern5
);
# Process all patterns
my %seen;
my $total_duplicates = 0;
foreach my $pattern (@all_patterns) {
    while ($content =~ /$pattern/g) {
        my $full_match = $&;
        if ($seen{$full_match}++) {
            $total_duplicates++;
            next;
        }         
        my $year;
        if ($pattern == $existing_pattern) {
            $year = ($full_match =~ /<bibcit[^>]*>(\d{4})/)[0];
        } else {
            $year = $+;
        }
        
        $citations{$full_match} = $year;
        $content =~ s/\Q$full_match\E//;
    }
}
print(Dumper(%seen));
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
    # print("$citation ======> $citations{$citation}\n");
    
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
print "Duplicate citations found: $total_duplicates\n";