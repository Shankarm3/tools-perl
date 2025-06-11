#!/usr/bin/perl
###############################################################################
# Script Name : citation_pattern_matcher.pl
# Description : Extracts and sorts citations from an XML file with <bibcit> tags.
# Author      : Shankar Dutt Mishra
# Created     : 10-06-2025
# Updated     : 10-06-2025
# Version     : 1.1
#
# Usage       : perl citation_pattern_matcher.pl <xml_file> <bibcit_ids>
#               perl citation_pattern_matcher.pl --help
#
# Notes       : Requires Perl modules: JSON, File::Basename, Text::Unidecode
#               The script reads an XML file, extracts citations, sorts them,
#               and outputs them in JSON format.
#               It handles large files, duplicates, and normalizes text.
###############################################################################

use strict;
use warnings;
use JSON;
use Text::Unidecode;
use Data::Dumper;

# Configuration
my $CONFIG = {
    max_file_size => 50 * 1024 * 1024,
    version       => '1.1',
};

# Global patterns config
my $global_patterns = {
    'pat-with-and' => '\((?:[^()]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>[;,]?\\s*)*\\s*and\\s+[^\\(\\)<>]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>\\)',
    'pat1-with-bracket' => '\\((?:e\\.g\\.\\s*(?:see)?)?([^<>\\)\\(]*?<bibcit\\b[^>]*>[^<>]*?<\\/bibcit>[,;]?)\\)',
    'pat2-with-bracket' => '\\((?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)\\)',
    'pat3-without-bracket' => '(?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)'
};

# Main execution
main();

# Validate input
sub validate_input {
    my ($file, $bibcit_ids) = @_;
    
    unless (-e $file) {
        die "Error: Input file '$file' does not exist\n";
    }
    unless (-r _) {
        die "Error: Cannot read input file '$file'\n";
    }
    
    my $size = -s $file;
    if ($size > $CONFIG->{max_file_size}) {
        die "Error: File '$file' exceeds maximum allowed size of " . 
            int($CONFIG->{max_file_size}/1024/1024) . "MB\n";
    }
    
    unless (defined $bibcit_ids && $bibcit_ids =~ /\S/) {
        die "Error: No bibcit IDs provided\n";
    }
    
    my @ids = map { 
        s/^\s+|\s+$//gr;
    } split /,/, $bibcit_ids;

    @ids = grep { /\S/ } @ids;
    
    unless (@ids) {
        die "Error: No valid bibcit IDs provided\n";
    }
    
    return @ids;
}

# Read XML file
sub read_xml_file {
    my ($file) = @_;
    
    open(my $in_fh, '<:encoding(UTF-8)', $file)
        or die "Error: Could not open input file '$file': $!\n";
    
    local $/;
    my $xml = <$in_fh>;
    close $in_fh;
    
    unless (defined $xml && length $xml) {
        die "Error: File '$file' is empty\n";
    }
    
    return $xml;
}

# Normalize XML
sub normalize_xml {
    my ($xml) = @_;
    
    $xml =~ s/\&amp;/\&/g;
    $xml =~ s/\&nbsp;/ /g;
    $xml =~ s/\xA0/ /g;
    $xml =~ s/<latex[^<>]*>.*?<\/latex>\s*.\s*//msg;
    $xml =~ s/\s+/ /g;
    $xml = unidecode($xml);
    
    return $xml;
}

# Build patterns
sub build_patterns {
    my ($bibcit_id) = @_;
    my $bibcit_pattern = qr{
        <bibcit\b
        [^>]*?
        rid\s*=\s*["']\Q$bibcit_id\E["']
        [^>]*?>
        [^<>]*
        <\/bibcit>
    }xis;

    my $author_pattern = qr{
        [A-Z][a-zA-Z\-\']+ 
        (?:
            (?:,\s*[A-Z][a-zA-Z\-\']+)* 
            (?:\s*&\s*[A-Z][a-zA-Z\-\']+)? 
        )?
        (?:\s+et\s*al\.)?
        \s*
    }x;

    return (
        qr{ \(\s* $author_pattern $bibcit_pattern \s* \) }xis,
        qr{ $author_pattern \(\s* $bibcit_pattern \s* \) }xis,
        qr{ $author_pattern $bibcit_pattern }xis,
    );
}

# Classify pattern type
sub classify_pattern_type {
    my ($match) = @_;
    return 'parens'        if $match =~ /^\([^<]*<bibcit[^<]*>[^<>]*<\/bibcit>\)$/;
    return 'author_parens' if $match =~ /^[^()]*\(<bibcit[^<]*>[^<>]*<\/bibcit>\)$/;
    return 'no_parens'     if $match =~ /^[^()]*<bibcit[^<]*>[^<>]*<\/bibcit>$/;
    return 'other';
}

# Find most common pattern type
sub find_most_common_type {
    my (%pattern_type_count) = @_;
    return (sort { $pattern_type_count{$b} <=> $pattern_type_count{$a} } keys %pattern_type_count)[0];
}

# Process bibcit ID
sub process_bibcit_id {
    my ($xml, $bibcit_id, $most_common_patterns_list) = @_;
    
    my @patterns = build_patterns($bibcit_id);
    my $xml_copy = $xml;
    my (%full_match_count, %pattern_type_count, %pattern_type_matches);
    my $found = 0;
    
    for my $pat (@patterns) {
        while ($xml_copy =~ /$pat/g) {
            $found = 1;
            my $match = $&;
            $match =~ s/^\s+|\s+$//g;
            $full_match_count{$match}++;
            my $type = classify_pattern_type($match);
            $pattern_type_count{$type}++;
            push @{$pattern_type_matches{$type}}, $match;
            $xml_copy =~ s/\Q$match\E//;
            pos($xml_copy) = 0;
        }
    }
    
    unless ($found) {
        return [undef, 0];
    }
    
    my $most_common_type = find_most_common_type(%pattern_type_count);
    my $most_common_pattern = '';
    
    if ($most_common_type && @{$pattern_type_matches{$most_common_type}}) {
        my @sorted = sort @{$pattern_type_matches{$most_common_type}};
        $most_common_pattern = $sorted[0];
        push(@$most_common_patterns_list, $most_common_pattern);
    }
    
    return [$most_common_pattern, 1];
}

# Process most common patterns
sub process_most_common_patterns {
    my ($xml, $patterns_ref, $total_bibcit_ids) = @_;
    my @patterns = @$patterns_ref;
    my $max_pattern_found = undef;
    foreach my $pattern (@patterns) {
        if ($pattern) {
            my $type = classify_pattern_type($pattern);
        } else {
        }
    }
    my $pattern_count = scalar @patterns;
    $$total_bibcit_ids = $pattern_count;
    if ($pattern_count > 0) {
        $max_pattern_found = find_matching_patterns_source_xml($xml, \@patterns, $pattern_count) || '';
        return $max_pattern_found;
    } else {
    }
    return "";
}

# Find matching patterns source XML
sub find_matching_patterns_source_xml {
    my ($xml, $patterns, $total_bibcit_ids) = @_;
    my $regex_pattern = get_regex_pattern($patterns, $total_bibcit_ids);
    my $count = 0;
    my $pattern_hash = {};
    my $replace_pattern =  qr{
        \([^\(\)<>]*<bibcit\b[^>]*?>.*?<\/bibcit>\)
    }xis;
    my $i = 0;
    foreach my $regex (@$regex_pattern) {
        $i++;
        while ($xml =~ /$regex/g) {
            my $count_bibcit = 0;
            if ($i == 1) {
                my $temp_str = $&;
                $count_bibcit = () = $temp_str =~ /<bibcit\b/gi;
            }
            if ($i == 1 && $total_bibcit_ids != $count_bibcit) {
                next;
            }
            $pattern_hash->{$regex}++;
            my $match = $&;
            $match =~ s/^\s+|\s+$//g;
            $count++;
            $xml =~ s/\Q$match\E//;
        }
        if( $i == 3) {
            $xml =~ s/$replace_pattern//g;
            next;
        }
    }
    my @sorted_keys = sort { $pattern_hash->{$b} <=> $pattern_hash->{$a} } keys %$pattern_hash;
    return $sorted_keys[0] if $count > 0;
    return undef;
}

# Get regex pattern
sub get_regex_pattern {
    my ($patterns, $pattern_count) = @_;
    return unless @$patterns;
    return [
        qr{
            \((?:[^()]*?<bibcit\b[^>]*>[^<>]*<\/bibcit>[;,]?\s*)*\s*and\s+[^\(\)<>]*?<bibcit\b[^>]*>[^<>]*<\/bibcit>\)
        }xi,
        qr{
            \((?:e\.g\.\s*(?:see)?)?([^<>\)\(]*?<bibcit\b[^>]*>[^<>]*?<\/bibcit>[,;]?){$pattern_count}\)
        }xi,
        qr{
            \((?:[A-Z][a-zA-Z\-\']+(?:\s+et\s+al\.)?\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>\s*[;,]?\s*){$pattern_count}\)
        }xi,
        qr{
            (?:[A-Z][a-zA-Z\-\']+(?:\s+et\s+al\.)?\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>\s*[;,]?\s*){$pattern_count}
        }xi,
    ];
}

# Main execution
sub main {
    if (grep { $_ eq '--help' || $_ eq '-h' } @ARGV) {
        print_help();
        exit 0;
    }
    
    if (@ARGV != 2) {
        print_help();
        exit 1;
    }

    my ($xml_file, $bibcit_ids_str) = @ARGV;
    my @ref_types = ();  
    my $ref_types_hash = {};  
    
    eval {
        my @ids = validate_input($xml_file, $bibcit_ids_str);
        
        my $xml = read_xml_file($xml_file);
        my $xml_copy = $xml;
        $xml = normalize_xml($xml);
        
        my @most_common_patterns_list;
        my @not_found_ids;
        my $total_bibcit_ids = 0;

        for my $bibcit_id (@ids) {
            my $found = 0;
            eval {
                my $result = process_bibcit_id($xml, $bibcit_id, \@most_common_patterns_list);
                if (ref($result) eq 'ARRAY') {
                    $found = $result->[1];
                }
            };
            
            if ($@ || !$found) {
                my $error = $@ || 'Not found';
                chomp $error;
                push @not_found_ids, $bibcit_id;
            }
        }
        
        if (!@most_common_patterns_list) {
            @not_found_ids = @ids;
            my %output = (
                status => 'partial',
                result => [],
                message => "No patterns found for any of the provided bibcit IDs: " . join(', ', @ids),
                missing_references => \@not_found_ids,
                timestamp => scalar localtime,
            );
            print JSON->new->pretty->encode(\%output);
            exit 0;
        }

        my $final_output;
        if (@most_common_patterns_list) {
            my $pattern_found = process_most_common_patterns(
                $xml_copy, 
                \@most_common_patterns_list, 
                \$total_bibcit_ids
            );
            $pattern_found = clean_pattern($pattern_found) if $pattern_found;
            $final_output = generate_output(
                $pattern_found, 
                \@most_common_patterns_list, 
                $global_patterns
            );
        }

        my %output = ( 
            status => 'success',
            result => $final_output // [],
            message => @not_found_ids ? "Some references were not found" : "",
            timestamp => scalar localtime,
        );

        if (@not_found_ids) {
            my $author_info = get_authors_from_references($xml_copy, \@not_found_ids);
            $output{'missing_references'} = {
                'ids' => \@not_found_ids,
                'authors' => $author_info
            };
        }

        my $json = JSON->new->pretty->canonical->encode(\%output);
        print $json;
        
    } or do {
        my $error = $@ || 'Unknown error';
        chomp $error;
        
        my %error_output = (
            status => 'error',
            message => $error,
            result => "",
            timestamp => scalar localtime,
        );
        
        print JSON->new->pretty->encode(\%error_output);
        exit 1;
    };
    
    exit 0;
}

# Clean pattern
sub clean_pattern {
    my ($pattern) = @_;
    return unless defined $pattern;
    $pattern =~ s/{\d+}//g;
    $pattern =~ s/^\(\?\^ix:\s*|\s*\)$//gs;
    return $pattern;
}

# Generate output
sub generate_output {
    my ($pattern_found, $patterns_list, $global_patterns) = @_;
    my $final_output;
    
    if ($pattern_found) {
        foreach my $key (keys %{$global_patterns}) {
            if ($pattern_found eq $global_patterns->{$key}) {
                if ($key eq 'pat1-with-bracket' || $key eq 'pat2-with-bracket') {
                    $final_output = "(" . join('; ', @$patterns_list) . ")";
                } elsif ($key eq 'pat3-without-bracket') {
                    $final_output = join('; ', @$patterns_list);
                } elsif ($key eq 'pat-with-and') {
                    my $temp = join('; ', @$patterns_list);
                    $temp =~ s/;(\s*[^<>]*<bibcit[^<>]*>[^<>]*<\/bibcit>)$/ and $1/g;
                    $temp =~ s/\s+/ /g;
                    $final_output = "($temp)";
                }
                last;
            }
        }
    }
    
    $final_output ||= "(" . join('; ', @$patterns_list) . ")";
    
    $final_output =~ s/^\(+/\(/;
    $final_output =~ s/\)+$/\)/;
    $final_output = remove_inner_parentheses($final_output);
    
    return $final_output;
}

# Remove inner parentheses
sub remove_inner_parentheses {
    my ($str) = @_;
    if ($str =~ /^\((.*)\)$/s) {
        my $inside = $1;
        $inside =~ s/[\(]//g;
        $inside =~ s/[\)]//g;
        return "($inside)";
    }
    return $str;
}

# Get authors from references
sub get_authors_from_references {
    my ($xml, $missing_refs) = @_;
    my %authors;
    
    foreach my $ref_id (@$missing_refs) {
        if ($xml =~ /<bib[^<>]*$ref_id[^<>]*>(.*?)<\/bib>/is) {
            my $ref_content = $1;
            my @authors;
            my $year;
            
            if ($ref_content =~ /<yr[^>]*>(.*?)<\/yr>/i) {
                $year = $1;
                $year =~ s/^\s+|\s+$//g;
            }
            
            while ($ref_content =~ /<au[^>]*>(.*?)<\/au>/gis) {
                my $au = $1;
                $au =~ s/<[^>]+>//g;
                $au =~ s/&nbsp;/ /g;
                $au =~ s/\s+/ /g;
                $au =~ s/^\s+|\s+$//g;
                push @authors, $au if $au;
            }
            
            my $link_id = 'link_' . sprintf("%08x", rand(0xffffffff));
            my $sno = $ref_id =~ /(\d+)/ ? $1 : $ref_id;
            my $author_string = join(', ', @authors);
            if (defined $year) {
                $author_string .= sprintf(
                    ' <bibcit rid="%s" title="bibcit" href="#" contenteditable="false" id="%s" sno="%s">%s</bibcit>',
                    $ref_id, $link_id, $sno, $year
                );
            }

            if ($ref_content =~ /<etal[^>]*>\s*et\s+al\s*\.\s*<\/etal>/i) {
                $author_string .= ' et al.';
            }
            
            $authors{$ref_id} = $author_string if $author_string;
        }
    }
    
    return \%authors;
}

# Print help
sub print_help {
    print <<"USAGE";
Citation Matcher v$CONFIG->{version}

Usage: $0 <xml_file> <bibcit_id1[,bibcit_id2,...]>

Options:
  -h, --help    Show this help message

Examples:
  $0 input.xml bib1,bib2,bib3
  $0 input.xml bib1,bib2

USAGE
}