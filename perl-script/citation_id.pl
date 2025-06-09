#!/usr/bin/perl
use strict;
use warnings;
use Text::Unidecode;
use Data::Dumper;
use Carp;

# Global patterns config
my $global_patterns = {
    'pat-with-and' => '\\((?:[^()]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>[;,]?\\s*)*\\s*and\\s+[^\\(\\)<>]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>\\)',
    'pat1-with-bracket' => '\\((?:e\\.g\\.\\s*(?:see)?)?([^<>\\)\\(]*?<bibcit\\b[^>]*>[^<>]*?<\\/bibcit>[,;]?)\\)',
    'pat2-with-bracket' => '\\((?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)\\)',
    'pat3-without-bracket' => '(?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)'
};

# Logging utility for info/debug output
sub log_info {
    my ($message) = @_;
    # print STDERR "[INFO] $message\n";
    print "[INFO]===> $message\n";
}

# Reads XML file and normalizes content
sub read_xml {
    my ($file) = @_;
    croak "No file provided" unless $file;
    open my $fh, '<:encoding(UTF-8)', $file or croak "Cannot open $file: $!";
    local $/;
    my $xml = <$fh>;
    close $fh;
    $xml = unidecode($xml);
    $xml =~ s/\&amp;/\&/g;
    $xml =~ s/\xA0/ /g;
    $xml =~ s/<latex[^<>]*>.*?<\/latex>\s*.\s*//msg;
    $xml =~ s/\s+/ /g;
    return $xml;
}

# Build regex patterns for a given bibcit_id
# Returns a list of regexes to match different citation forms
sub build_patterns {
    my ($bibcit_id) = @_;
    croak "No bibcit_id provided" unless defined $bibcit_id;
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

# Classify pattern type for a matched citation string
sub classify_pattern_type {
    my ($match) = @_;
    return 'parens'        if $match =~ /^\([^<]*<bibcit[^<]*>[^<>]*<\/bibcit>\)$/;
    return 'author_parens' if $match =~ /^[^()]*\(<bibcit[^<]*>[^<>]*<\/bibcit>\)$/;
    return 'no_parens'     if $match =~ /^[^()]*<bibcit[^<]*>[^<>]*<\/bibcit>$/;
    return 'other';
}

# Find the most common pattern type from a hash of counts
sub find_most_common_type {
    my (%pattern_type_count) = @_;
    return (sort { $pattern_type_count{$b} <=> $pattern_type_count{$a} } keys %pattern_type_count)[0];
}

# Process a single bibcit_id and return its most common pattern
sub process_bibcit_id {
    my ($xml, $bibcit_id, $most_common_patterns_list) = @_;
    croak "No XML provided" unless $xml;
    croak "No bibcit_id provided" unless $bibcit_id;

    my @patterns = build_patterns($bibcit_id);
    my $xml_copy = $xml;
    my (%full_match_count, %pattern_type_count, %pattern_type_matches);

    for my $pat (@patterns) {
        while ($xml_copy =~ /$pat/g) {
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
    my $most_common_type = find_most_common_type(%pattern_type_count);

    if (%full_match_count) {
        log_info("All matched patterns for bibcit id '$bibcit_id':");
        for my $m (sort keys %full_match_count) {
           log_info($m);
        }
    }

    my $most_common_pattern = '';
    if ($most_common_type && @{$pattern_type_matches{$most_common_type}}) {
        my @sorted = sort @{$pattern_type_matches{$most_common_type}};
        log_info("Most common pattern type: $most_common_type");
        log_info($sorted[0]);
        $most_common_pattern = $sorted[0];
        push(@$most_common_patterns_list, $most_common_pattern);
    } else {
        log_info("No patterns found for bibcit id '$bibcit_id'.");
    }
    return $most_common_pattern;
}

# Process all most common patterns and return the max pattern found
sub process_most_common_patterns {
    my ($xml, $patterns_ref, $total_bibcit_ids) = @_;
    my @patterns = @$patterns_ref;
    log_info("Processing most common patterns... @patterns");
    my $max_pattern_found = undef;
    foreach my $pattern (@patterns) {
        if ($pattern) {
            my $type = classify_pattern_type($pattern);
            log_info("Pattern: $pattern");
            log_info("Type: $type");
        } else {
            log_info("No pattern found.");
        }
    }
    my $pattern_count = scalar @patterns;
    $$total_bibcit_ids = $pattern_count;
    if ($pattern_count > 0) {
        log_info("Total patterns processed: $pattern_count");
        $max_pattern_found = find_matching_patterns_source_xml($xml, \@patterns, $pattern_count) || '';
        log_info("Max pattern found: $max_pattern_found");
        return $max_pattern_found;
    } else {
        log_info("No patterns to process.");
    }
    return "";
}

# Find matching patterns in source XML
sub find_matching_patterns_source_xml {
    my ($xml, $patterns, $total_bibcit_ids) = @_;
    my $regex_pattern = get_regex_pattern($patterns, $total_bibcit_ids);
    log_info("Regex pattern for source XML: @{$regex_pattern}");
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
                log_info("Pattern with 'and' found: $&");
                $count_bibcit = () = $temp_str =~ /<bibcit\b/gi;
                log_info("Dollar I======> is equal to 1 Exiting as this is the most common pattern type. $count_bibcit bibcit tags found. and required $total_bibcit_ids bibcit ids.");
            }
            if ($i == 1 && $total_bibcit_ids != $count_bibcit) {
                log_info("skipping this instance.....");
                next;
            }
            $pattern_hash->{$regex}++;
            my $match = $&;
            $match =~ s/^\s+|\s+$//g;
            $count++;
            log_info("Matched pattern in source XML: Count => $count, $match");
            $xml =~ s/\Q$match\E//;
        }
        if( $i == 3) {
            $xml =~ s/$replace_pattern//g;
            next;
        }
    }

    log_info(Dumper($pattern_hash));
    my @sorted_keys = sort { $pattern_hash->{$b} <=> $pattern_hash->{$a} } keys %$pattern_hash;
    log_info(Dumper(@sorted_keys));
    log_info("Sorted keys: @sorted_keys");
    return $sorted_keys[0] if $count > 0;
    return undef;
}

# Get regex patterns for matching
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

# Print help message
sub print_help {
    print <<"USAGE";
Usage: $0 <xml_file> <bibcit_id1[,bibcit_id2,...]>

Finds and classifies citation patterns in XML files.

Arguments:
  <xml_file>                Path to the XML file to process.
  <bibcit_id1[,id2,...]>    One or more bibcit IDs, comma-separated.

Options:
  -h, --help                Show this help message.

Example:
  perl $0 input.xml B1,B2,B3

USAGE
    exit 0;
}

# Main entry point
sub main {
    if (grep { $_ eq '--help' || $_ eq '-h' } @ARGV) {
        print_help();
    }
    if (@ARGV != 2) {
        die "Usage: $0 <xml_file> <bibcit_id1[,bibcit_id2,...]>\n";
    }

    my ($xml_file, $bibcit_ids) = @ARGV;

    croak "XML file does not exist: $xml_file" unless -e $xml_file;
    croak "No bibcit IDs provided" unless $bibcit_ids =~ /\S/;

    my $xml = read_xml($xml_file);
    my $xml_copy = $xml;
    my @ids = map { s/^\s+|\s+$//gr } split /,/, $bibcit_ids;
    my @most_common_patterns_list;
    my $total_bibcit_ids = 0;

    for my $bibcit_id (@ids) {
        process_bibcit_id($xml, $bibcit_id, \@most_common_patterns_list);
    }

    my $pattern_found = process_most_common_patterns($xml_copy, \@most_common_patterns_list, \$total_bibcit_ids);
    $pattern_found =~ s/{\d+}//g if $pattern_found;
    $pattern_found =~ s/^\(\?\^ix:\s*|\s*\)$//gs if $pattern_found;

    foreach my $key (keys %{$global_patterns}) {
        log_info("Checking pattern===> $key");
        log_info("Global pattern=====> $global_patterns->{$key}");
        if ($pattern_found && $pattern_found eq $global_patterns->{$key}) {
            if ($key eq 'pat1-with-bracket' || $key eq 'pat2-with-bracket') {
                print "(".join('; ', @most_common_patterns_list).")", "\n";
            } elsif ($key eq 'pat3-without-bracket') {
                print join('; ', @most_common_patterns_list), "\n";
            } elsif ($key eq 'pat-with-and') {
                my $final_pattern_str = join('; ', @most_common_patterns_list);
                $final_pattern_str =~ s/;(\s*[^<>]*<bibcit[^<>]*>[^<>]*<\/bibcit>)$/ and $1/g;
                $final_pattern_str =~ s/\s+/ /g;
                print "($final_pattern_str)\n";
            }
            last;
        }
    }

    if(!$pattern_found){
        print "(".join('; ', @most_common_patterns_list).")", "\n";
    }
}

main();