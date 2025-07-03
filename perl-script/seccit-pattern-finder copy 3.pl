#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use JSON;
use POSIX 'strftime';

# Check command line arguments
die "Usage: $0 <xml_file> <comma_separated_ids> <tag_name>\n" unless @ARGV == 3;
my ($xml_file, $ids_str, $tag_name) = @ARGV;

# Initialize result variables
my @found_citations;
my @missing_ids;

# Read the entire file with UTF-8 encoding
open(my $fh, '<:encoding(UTF-8)', $xml_file) or die "Could not open file '$xml_file': $!\n";
my $content = do { local $/; <$fh> };
$content =~ s/\xA0/ /g;
close $fh;

# Find the maximum apt_id in the document
my $max_apt_id = 0;
$content =~ /apt_id="(\d+)"/g;
while ($content =~ /apt_id="(\d+)"/g) {
    $max_apt_id = $1 if $1 > $max_apt_id;
}

# Process each section ID
my @ids = split(/,/, $ids_str);
foreach my $sect_id (@ids) {
    $sect_id =~ s/^\s+|\s+$//g;
    my $found = 0;
    
    my $section_prefix = "";
    if ($content =~ /(Sec\.|Section)?\s*(<seccit[^>]*rid="\Q$sect_id\E"[^>]*>.*?<\/seccit>)/i) {
        $section_prefix = "$1" if $1;
        push @found_citations, "$section_prefix $2";
        $found = 1;
        next;
    }
    
    if ($content =~ /<sect\d+\s+[^>]*?apt_id="\Q$sect_id\E"[^>]*>\s*<ti[^>]*?\bsno="([^"]*)"[^>]*>/s) {
        my $sno = $1;
        my $sect_match = $&;
        
        my $sect_apt_id = $sect_id;
        if ($sect_match =~ /apt_id="([^"]*)"/) {
            $sect_apt_id = $1;
        }
        
        $max_apt_id++;
        my $new_seccit = qq{<seccit rid="$sect_apt_id" title="seccit" href="#" contenteditable="false" id="seccit_$max_apt_id" apt_id="$max_apt_id">$sno</seccit>};
        if($section_prefix) {
            push @found_citations, "$section_prefix $new_seccit";
        } else {
            push @found_citations, "$new_seccit";
        }
        $found = 1;
    }
    
    push @missing_ids, $sect_id unless $found;
}

# After finding sections, store both the number, rid, and apt_id
my @sections;
foreach my $citation (@found_citations) {
    if ($citation =~ /(Sec\.|Section)?\s*<seccit[^>]*?rid="([^<>]*?)"[^>]*(?:apt_id="([^"]*?)")?[^>]*?>([^<]+)<\/seccit>/) {
        my ($prefix, $rid, $apt_id, $num) = ($1, $2, $3, $4);
        push @sections, { 
            prefix => $prefix || "",
            rid => $rid, 
            apt_id => $apt_id || $max_apt_id + 1, 
            num => $num 
        };
    }
}

# Extract just the numbers for range finding
my @section_numbers = map { $_->{num} } @sections;
my @ranges = find_ranges(@section_numbers);

# Create a mapping of number to section info
my %num_to_section;
foreach my $section (@sections) {
    $num_to_section{$section->{num}} = $section;
}

# Process the ranges to create the final output
my @output;
foreach my $range (@ranges) {
    if ($range =~ /^(\d+)-(\d+)$/) {
        # This is a range
        my ($start, $end) = ($1, $2);
        my @range_sections = grep { 
            $_->{num} =~ /^\d+$/ && 
            $_->{num} >= $start && 
            $_->{num} <= $end 
        } @sections;
        
        if (@range_sections) {
            my @rids = map { $_->{rid} } @range_sections;
            my $all_rids = join(' ', @rids);
            $max_apt_id++;
            my $prefix = $range_sections[0]{prefix} || 'Section';
            push @output, qq{$prefix <seccit rid="$all_rids" title="seccit" href="#" contenteditable="false" id="seccit_$max_apt_id" apt_id="$max_apt_id">$start-$end</seccit>};
        }
    } else {
        if (exists $num_to_section{$range}) {
            my $section = $num_to_section{$range};
            $max_apt_id++;
            my $prefix = $section->{prefix} || 'Section';
            push @output, qq{$prefix <seccit rid="$section->{rid}" title="seccit" href="#$section->{rid}" contenteditable="false" id="seccit_$max_apt_id" apt_id="$max_apt_id">$range</seccit>};
        }
    }
}

# Prepare the final result
my $result = {
    message => @missing_ids ? "Some section IDs not found: " . join(', ', @missing_ids) : "",
    result => join(', ', @output),
    status => @missing_ids ? "partial" : "success",
    missing_ids => \@missing_ids,
    timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime)
};

# The find_ranges sub remains the same
sub find_ranges {
    my @numbers = @_;
    return () unless @numbers;
    
    my (@whole, @decimals, @alpha_numeric);
    foreach my $num (@numbers) {
        if ($num =~ /^\d+$/) {
            push @whole, $num;
        } elsif ($num =~ /^[A-Za-z0-9]+$/) {
            push @alpha_numeric, $num;
        } else {
            push @decimals, $num;
        }
    }
    my @result;
    
    if (@whole) {
        @whole = sort { $a <=> $b } @whole;
        my $start = $whole[0];
        my $prev = $start;
        
        for my $i (1..$#whole) {
            if ($whole[$i] == $prev + 1) {
                $prev = $whole[$i];
            } else {
                if ($start == $prev) {
                    push @result, $start;
                } else {
                    push @result, "$start-$prev";
                }
                $start = $prev = $whole[$i];
            }
        }
        if ($start == $prev) {
            push @result, $start;
        } else {
            push @result, "$start-$prev";
        }
    }
    
    push @result, sort { $a <=> $b } @decimals;

    push @result, sort { $a cmp $b } @alpha_numeric;

    return @result;
}

my $json = JSON->new->pretty(1)->encode($result);
print $json;