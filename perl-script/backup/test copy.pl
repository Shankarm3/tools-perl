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

# while ($content =~ /(\([^)]*?<bibcit\s+[^>]*>(\d{4})<\/bibcit>[^)]*\))/g) {
#     my $full_match = $1;
#     my $year = $2;
#     $citations{$full_match} = $year;
#     $content =~ s/\Q$full_match\E//;
# }

my $pattern = qr{
    \(              
    [^(]*?
    <bibcit\b[^>]*>  
    \d{4}            
    </bibcit>        
    [^)]*            
    \)
}x;

# In your loop:
while ($content =~ /($pattern)/g) {
    my $full_match = $1;
    my $year = ($full_match =~ /<bibcit[^>]*>(\d{4})/)[0];  # Extract first year
    $citations{$full_match} = $year;
    $content =~ s/\Q$full_match\E//;
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