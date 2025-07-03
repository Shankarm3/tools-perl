#!/usr/bin/perl
###############################################################################
# Script Name : citation_pattern_matcher.pl
# Description : Extracts and sorts citations from an XML file with <bibcit> tags.
# Author      : Shankar Dutt Mishra
# Created     : 10-06-2025
# Updated     : 03-07-2025
# Version     : 1.4
#
# Usage       : perl citation_pattern_matcher.pl <xml_file> <bibcit_ids> [tagname]
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
use POSIX qw(strftime);
use Text::Unidecode;
use utf8;
use Data::Dumper;
use open ':std', ':encoding(UTF-8)';

binmode(STDOUT, ":utf8");
binmode(STDERR, ':utf8');

# Configuration
my $CONFIG = {
    max_file_size => 50 * 1024 * 1024,
    version       => '1.4',
};

# Global patterns config
my $global_patterns = {
    'pat-with-and' => '\((?:[^()]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>[;,]?\\s*)*\\s*and\\s+[^\\(\\)<>]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>\\)',
    'pat1-with-bracket' => '\\((?:e\\.g\\.\\s*(?:see)?)?([^<>\\)\\(]*?<bibcit\\b[^>]*>[^<>]*?<\\/bibcit>[,;]?)\\)',
    'pat2-with-bracket' => '\\((?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)\\)',
    'pat3-without-bracket' => '(?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)'
};

# Patterns for appcit, figcita, tbcita
my $appendix_patterns = {
    appcit => qr{\(?(?:Appendix|App)\.?\s*},
    figcita => qr{\(?(?:Fig|Figure)\.?\s*},
    tbcita => qr{\(?(?:Tab|Table)\.?\s*}
};

# Character map
our %char_map = (
    'Agrave'    => "\x{00C0}",  # À
    'Aacute'    => "\x{00C1}",  # Á
    'Acirc'     => "\x{00C2}",  # Â
    'Atilde'    => "\x{00C3}",  # Ã
    'Auml'      => "\x{00C4}",  # Ä
    'Aring'     => "\x{00C5}",  # Å
    'Ccedil'    => "\x{00C7}",  # Ç
    'Egrave'    => "\x{00C8}",  # È
    'Eacute'    => "\x{00C9}",  # É
    'Ecirc'     => "\x{00CA}",  # Ê
    'Euml'      => "\x{00CB}",  # Ë
    'Igrave'    => "\x{00CC}",  # Ì
    'Iacute'    => "\x{00CD}",  # Í
    'Icirc'     => "\x{00CE}",  # Î
    'Iuml'      => "\x{00CF}",  # Ï
    'Ntilde'    => "\x{00D1}",  # Ñ
    'Ograve'    => "\x{00D2}",  # Ò
    'Oacute'    => "\x{00D3}",  # Ó
    'Ocirc'     => "\x{00D4}",  # Ô
    'Otilde'    => "\x{00D5}",  # Õ
    'Ouml'      => "\x{00D6}",  # Ö
    'Ugrave'    => "\x{00D9}",  # Ù
    'Uacute'    => "\x{00DA}",  # Ú
    'Ucirc'     => "\x{00DB}",  # Û
    'Uuml'      => "\x{00DC}",  # Ü
    'Yacute'    => "\x{00DD}",  # Ý
    'Thorn'     => "\x{00DE}",  # Þ
    'Lstrok'    => "\x{0141}",  # Ł
    'Scedil'    => "\x{015E}",  # Ş
    'Zcaron'    => "\x{017D}",  # Ž
    'agrave'    => "\x{00E0}",  # à
    'aacute'    => "\x{00E1}",  # á
    'acirc'     => "\x{00E2}",  # â
    'atilde'    => "\x{00E3}",  # ã
    'auml'      => "\x{00E4}",  # ä
    'aring'     => "\x{00E5}",  # å
    'ccedil'    => "\x{00E7}",  # ç
    'egrave'    => "\x{00E8}",  # è
    'eacute'    => "\x{00E9}",  # é
    'ecirc'     => "\x{00EA}",  # ê
    'euml'      => "\x{00EB}",  # ë
    'igrave'    => "\x{00EC}",  # ì
    'iacute'    => "\x{00ED}",  # í
    'icirc'     => "\x{00EE}",  # î
    'iuml'      => "\x{00EF}",  # ï
    'ntilde'    => "\x{00F1}",  # ñ
    'ograve'    => "\x{00F2}",  # ò
    'oacute'    => "\x{00F3}",  # ó
    'ocirc'     => "\x{00F4}",  # ô
    'otilde'    => "\x{00F5}",  # õ
    'ouml'      => "\x{00F6}",  # ö
    'ugrave'    => "\x{00F9}",  # ù
    'uacute'    => "\x{00FA}",  # ú
    'ucirc'     => "\x{00FB}",  # û
    'uuml'      => "\x{00FC}",  # ü
    'yacute'    => "\x{00FD}",  # ý
    'thorn'     => "\x{00FE}",  # þ
    'yuml'      => "\x{00FF}",  # ÿ
    'szlig'     => "\x{00DF}",  # ß
    'lstroke'   => "\x{0142}",  # ł
    'scedil'    => "\x{015F}",  # ş
    'zcaron'    => "\x{017E}",  # ž
    'cacute'    => "\x{0107}",  # ć
    'ccaron'    => "\x{010D}",  # č
    'dcaron'    => "\x{010F}",  # ď
    'eogonek'   => "\x{0119}",  # ę
    'nacute'    => "\x{0144}",  # ń
    'sacute'    => "\x{015B}",  # ś
    'scaron'    => "\x{0161}",  # š
    'tcaron'    => "\x{0165}",  # ť
    'udblac'    => "\x{0171}",  # ű
    'zacute'    => "\x{017A}",  # ź
);


# Main execution
main();

# Main execution
sub main {
    if (@ARGV == 1 && ($ARGV[0] eq '--help' || $ARGV[0] eq '-h')) {
        print_help();
        exit 0;
    }
    
    if (@ARGV != 3) {
        warn "Error: Incorrect number of arguments\n\n";
        print_help();
        exit 1;
    }
    
    my ($xml_file, $bibcit_ids_str, $tag_name) = @ARGV;

    if ($tag_name ne 'bibcit' && $tag_name ne 'figcit' && $tag_name ne 'tbcit' && $tag_name ne 'seccit' && $tag_name ne 'appcit' && $tag_name ne 'figcita' && $tag_name ne 'tbcita') {
        warn "Error: Invalid tag_name '$tag_name'. Must be either 'bibcit' or 'figcit' or 'tbcit' or 'seccit' or 'appcit' or 'figcita' or 'tbcita'\n\n";
        print_help();
        exit 1;
    }

    my @ids = validate_input($xml_file, $bibcit_ids_str);
        
    my $xml = read_xml_file($xml_file);
    my $xml_copy = normalize_xml($xml);
    my $xml_copy_2 = normalize_xml($xml);
    $xml = normalize_xml($xml);

    if($tag_name eq 'bibcit') {
        process_bibcits_no_uno($xml, $xml_copy, $xml_copy_2, $bibcit_ids_str, @ids);
    }
    elsif($tag_name eq 'figcit') {
        process_figcit_references($xml, $bibcit_ids_str);
    }
    elsif($tag_name eq 'tbcit') {
        process_tbcit_references($xml, $bibcit_ids_str);
    }
    elsif($tag_name eq 'seccit') {
        process_seccit_references($xml, $bibcit_ids_str);
    }
    elsif($tag_name eq 'appcit' or $tag_name eq 'figcita' or $tag_name eq 'tbcita') {
        process_appcits_figcita_tbcita($xml, $bibcit_ids_str, $tag_name);
    }
    else {
        warn "Error: Invalid tag_name '$tag_name'. Must be either 'bibcit' or 'figcit' or 'tbcit' or 'seccit'\n\n";
        print_help();
        exit 1;
    }
 
    exit 1;
}

# Process bibcits numbered and un numbered
sub process_bibcits_no_uno {
    my ($xml, $xml_copy, $xml_copy_2, $bibcit_ids_str, @ids) = @_;
    eval {
        
        my @most_common_patterns_list;
        my @not_found_ids;
        my $total_bibcit_ids = 0;
        my $final_output = '';
        my @numbered_references;

        my $is_numbered_reference = is_numbered_reference($xml);
        my %combined_output = (
            status => 'success',
            message => '',
            result => '',
            timestamp => scalar localtime,
        );

        if ($is_numbered_reference == 0) {
            $xml_copy_2 =~ s/<ref[^<>]*type="arabic"[^<>]*>.*?<\/ref>//isx;
            for my $bibcit_id (@ids) {
                my $found = 0;
                eval {
                    if(check_bibcit_id_in_ref($xml_copy_2, $bibcit_id)) {
                        my $result = process_bibcit_id_uno($xml_copy_2, $bibcit_id, \@most_common_patterns_list);
                        if (ref($result) eq 'ARRAY') {
                            $found = $result->[1];
                        }
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
            }

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
                $final_output = remove_inner_parentheses($final_output) if $final_output;
            }

            $combined_output{result} = $final_output if $final_output;

            if (@not_found_ids) {
                my $author_info = get_authors_from_references($xml_copy_2, \@not_found_ids);
        
                if (keys %$author_info) {
                    my @all_citations;
                    push @all_citations, $final_output if $final_output;
                    foreach my $id (@not_found_ids) {
                        if(check_bibcit_id_in_ref($xml_copy_2, $id)) {
                            push @all_citations, $author_info->{$id} if exists $author_info->{$id};
                        }
                    }
                    my $final_result = "(" . join("; ", @all_citations) . ")";
                    $combined_output{result} = remove_inner_parentheses($final_result);
                }
            }
        }

        my @bibcit_ids = process_bibcit_ids_no($xml, $bibcit_ids_str);
        my $max_bibcit_id = find_max_id($xml, 'id="bibcit_(\\d+)"');
        my $max_apt_id = find_max_id($xml, 'apt_id="(\\d+)"');
        my $ranges = find_consecutive_ranges(@bibcit_ids);
        my %bib_info = extract_bib_info($xml, @bibcit_ids);
        my @bibcit_tags = generate_bibcit_tags($ranges, \%bib_info, \$max_bibcit_id, \$max_apt_id);

        if (@bibcit_tags) {
            my $numbered_refs = print_results($xml, @bibcit_tags);
            $combined_output{result} = $combined_output{result} 
                ? "$combined_output{result}, $numbered_refs" 
                : $numbered_refs;
        }

        if (length($combined_output{result}) == 0) {
            $combined_output{status} = 'error';
        }
        else {
            $combined_output{result} =~ s/\)(.*?)$/$1\)/six;
        }

        if(length($combined_output{result}) == 0) {
            $combined_output{message} = "Some references were not found @not_found_ids" if @not_found_ids;
            $combined_output{missing_ids} = \@not_found_ids;
        }

        $combined_output{result} = restore_unicode($combined_output{result});
        my $json = JSON->new->pretty->canonical->encode(\%combined_output);
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
        
        print JSON->new->pretty->encode_json(\%error_output);
        exit 1;
    };

}

# Process figcits numbered
sub process_figcit_references {
    my ($xml, $figcit_ids_str) = @_;

    my %all_fig_ids;
    while ($xml =~ /<fig[^>]*?id="((?:fig)?\d+)"[^>]*>/g) {
        $all_fig_ids{$1} = 1;
    }
    my @missing_ids = grep { !exists $all_fig_ids{$_} } split(/\s*,\s*/, $figcit_ids_str);
    my @figcit_ids = process_figcit_ids($xml, $figcit_ids_str);
    my $max_figcit_id = find_max_id($xml, 'id="figcit_(\d+)"') || 9999; 
    my $max_apt_id = find_max_id($xml, 'apt_id="(\d+)"') || 9999;         
    my $ranges = find_consecutive_ranges(@figcit_ids);
    my %fig_info = extract_fig_info($xml, @figcit_ids);
    my @figcit_tags = generate_figcit_tags($ranges, \%fig_info, \$max_figcit_id, \$max_apt_id, $xml);

    print_figcits_results(\@figcit_tags, $xml, \@missing_ids);
}

# Process tbcits references
sub process_tbcit_references {
    my ($xml, $tbcit_ids_str) = @_;

    my @tbcit_ids = split(/,/, $tbcit_ids_str);
    my $max_apt_id = find_max_id($xml, 'apt_id="(\d+)"');

    my @found_results;
    my @missing_ids;

    foreach my $tbcit_id (@tbcit_ids) {
        $tbcit_id =~ s/^\s+|\s+$//g;
        next unless $tbcit_id;
        
        my $result = process_single_tbcit($xml, $tbcit_id, \$max_apt_id);
        if ($result->{found}) {
            push @found_results, $result->{tag};
        } else {
            push @missing_ids, $tbcit_id;
        }
    }

    my $result = generate_tbcit_response(\@found_results, \@missing_ids);
    print $result
}

# Process seccits references
sub process_seccit_references {
    my ($xml, $seccit_ids_str) = @_;

    my $max_apt_id = find_max_id($xml, 'apt_id="(\\d+)"');
    my ($found_citations, $missing_ids) = process_section_ids($xml, $seccit_ids_str, \$max_apt_id);

    my $result = process_section_citations($found_citations, $missing_ids, $max_apt_id);
    print JSON->new->pretty(1)->encode($result);

}

# Process appcits figcita tbcita references
sub process_appcits_figcita_tbcita {
    my ($content, $appcit_ids, $tag_name) = @_;
    my @appcit_ids = split(/,/, $appcit_ids);
    my @result_appcits;
    my @missing_ids;
    
    my ($prefix, $max_link_num) = find_max_link_number($content);

    foreach my $appcit_id (@appcit_ids) {
        my $found = 0;
        
        $found = try_direct_match(\$content, \@result_appcits, \$prefix, \$max_link_num, $appcit_id, $tag_name);
        
        unless ($found) {
            $found = try_pattern_matching(\$content, \@result_appcits, \$prefix, \$max_link_num, $appcit_id, $tag_name);
        }
        
        push @missing_ids, $appcit_id unless $found;
    }
    generate_appcit_result(\@result_appcits, \@missing_ids);
}

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
    
    open(my $in_fh, '<', $file)
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
    while (my ($name, $char) = each %char_map) {
        $xml =~ s/\Q$char\E/$name/g;
    }

    $xml =~ s/&amp;/\&/g;
    $xml =~ s/&nbsp;/ /g;
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
sub process_bibcit_id_uno {
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

# Check if reference is numbered
sub is_numbered_reference {
    my ($xml) = @_;
    if ($xml =~ /<ref[^<>]*?type="([a-z]+)"[^<>]*?>/) {
        my $type = $1;
        if($type eq 'arabic') {
            return 1;
        }
        elsif($type eq 'uno') {
            return 0;
        }
        elsif($type eq 'lowerroman') {
            return 0;
        }
        elsif($type eq 'upperroman') {
            return 0;
        }
        elsif($type eq 'loweralpha') {
            return 0;
        }
        elsif($type eq 'upperalpha') {
            return 0;
        }
        else {
            return 0;
        }
    }
    
    return 0;
}

# Check if bibcit id is in ref
sub check_bibcit_id_in_ref {
    my ($xml, $bibcit_id) = @_;
    
    while ($xml =~ /(<ref\b[^>]*\btype="uno"[^>]*>.*?<\/ref>)/gis) {
        my $ref_content = $1;
        
        if ($ref_content =~ /<bib\b[^>]*\b\Q$bibcit_id\E[^>]*>/i) {
            my $nested_refs = 0;
            my $content = $ref_content;
            while ($content =~ /<ref[^>]*>/gi) {
                $nested_refs++;
            }
            $nested_refs--;
            
            if ($nested_refs == 0) {
                return 1;
            }
        }
    }
    
    return 0;
}

# Process bibcit ids numbered
sub process_bibcit_ids_no {
    my ($content, $ids_str) = @_;
    my @apt_ids = split /,/, $ids_str;
    my @sno_ids;
    
    foreach my $apt_id (@apt_ids) {
        if ($content =~ /<bib[^>]*?sno="([^"]+)"[^>]*?apt_id="\Q$apt_id\E"/) {
            push @sno_ids, $1;
        } else {
            # warn "Warning: Could not find bib entry with apt_id=$apt_id\n";
        }
    }
    
    if (@sno_ids && $sno_ids[0] =~ /^\d+$/) {
        return sort { $a <=> $b } @sno_ids;
    } else {
        return sort @sno_ids;
    }
}

# Find max id
sub find_max_id {
    my ($content, $pattern) = @_;
    my $max_id = 0;
    while ($content =~ /$pattern/g) {
        $max_id = $1 if $1 > $max_id;
    }
    return $max_id + 1;
}

# Find consecutive ranges
sub find_consecutive_ranges {
    my @numbers = @_;
    return [] unless @numbers;
    
    if ($numbers[0] =~ /^\d+$/) {
        @numbers = sort { $a <=> $b } @numbers;
    } else {
        @numbers = sort @numbers;
    }
    
    my @ranges;
    my @current_range = ($numbers[0]);
    
    for my $i (1..$#numbers) {
        if ($numbers[$i] =~ /^\d+$/ && $numbers[$i-1] =~ /^\d+$/) {
            if ($numbers[$i] == $numbers[$i-1] + 1) {
                push @current_range, $numbers[$i];
                next;
            }
        } else {
            if (length($numbers[$i]) == 1 && length($numbers[$i-1]) == 1 &&
                ord($numbers[$i]) == ord($numbers[$i-1]) + 1) {
                push @current_range, $numbers[$i];
                next;
            }
        }
        push @ranges, [@current_range];
        @current_range = ($numbers[$i]);
    }
    push @ranges, \@current_range if @current_range;
    return \@ranges;
}

sub extract_bib_info {
    my ($content, @sno_ids) = @_;
    my %bib_info;
    foreach my $sno (@sno_ids) {
        if ($content =~ /<bib\s+[^>]*?sno="\Q$sno\E"[^>]*?apt_id="([^"]+)"/) {
            my $apt_id = $1;
            $bib_info{$sno}{apt_id} = $apt_id;
            $bib_info{$sno}{sno} = $sno;
        } else {
            warn "Warning: Could not find bib entry with sno=$sno\n";
        }
    }
    return %bib_info;
}

sub generate_bibcit_tags {
    my ($ranges, $bib_info, $max_bibcit_id_ref, $max_apt_id_ref) = @_;
    my @bibcit_tags;
    foreach my $range (@$ranges) {
        my @ids = @$range;
        my @apt_ids = map { $bib_info->{$_}{apt_id} } @ids;
        my @snos = map { $bib_info->{$_}{sno} } @ids;
        
        my $range_text = @ids > 1 ? "$ids[0]-$ids[-1]" : $ids[0];
        
        my $bibcit = qq(<bibcit rid=") . join(" ", @apt_ids) . 
                      qq(" title="bibcit" href="#" contenteditable="false" ) .
                      qq(id="bibcit_$$max_bibcit_id_ref" ) .
                      qq(sno=") . join(" ", @snos) . 
                      qq(" apt_id="$$max_apt_id_ref">$range_text</bibcit>);
        
        push @bibcit_tags, $bibcit;
        $$max_bibcit_id_ref++;
        $$max_apt_id_ref++;
    }
    
    return @bibcit_tags;
}

sub print_results {
    my ($content, @bibcit_tags) = @_;
    my $output = join("\n", @bibcit_tags);
    my $num_tags = scalar @bibcit_tags;
    my $brackets_pattern = qr/\[(\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>(\s*[,;]?\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>\s*[,;]?)+)\s*\]/;
    my $parens_pattern = qr/\((\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>(\s*[,;]?\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>\s*[,;]?)+)\s*\)/;
    my $brackets_pattern2 = qr/[\[\(]\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>\s*[\]\)]/;

    if ($content =~ $brackets_pattern || $content =~ $parens_pattern || $content =~ $brackets_pattern2) {
        my $matched = $&;
        my $content_inside = $1;
        my $open_char = substr($matched, 0, 1);
        my $close_char = $open_char eq '[' ? ']' : ')';
        
        my $separator = '';
        if ($content_inside && $content_inside =~ /<bibcit\b[^>]*?>[^<>]*<\/bibcit>(\s*[,;]?)\s*<bibcit/) {
            $separator = $1.' ' || ', '; 
        }
        if(scalar @bibcit_tags > 0) {
            $output = $open_char . 
                    join($separator, @bibcit_tags) . 
                    $close_char;
        }
    }

    return $output;
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
                    $final_output = join('; ', map { $_ =~ s/^\(|\)$//gr } @$patterns_list);
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
    
    $final_output =~ s/^(?:\()+/\(/;
    $final_output =~ s/(?:\))+$/\)/;
    $final_output = remove_inner_parentheses($final_output);
    
    return $final_output;
}

# Remove inner parentheses
sub remove_inner_parentheses {
    my ($str) = @_;
    $str =~ s/\(\)//g;
    $str =~ s/\[\]//g;
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

    my ($link_max_id, $prefix) = get_max_link_id($xml);

    foreach my $ref_id (@$missing_refs) {
        if ($xml =~ /<bib[^<>]*id="[^<>]*$ref_id"[^<>]*>(.*?)<\/bib>/is) {
            my $ref_content = $1;
            my @authors;
            my $year;
            
            if ($ref_content =~ /<yr[^>]*>(.*?)<\/yr>/i) {
                $year = $1;
                $year =~ s/^\s+|\s+$//g;
            }
            
            while ($ref_content =~ /<s[^>]*>(.*?)<\/s>/gis) {
                my $au = $1;
                $au =~ s/<[^>]+>//g;
                $au =~ s/&nbsp;/ /g;
                $au =~ s/\s+/ /g;
                $au =~ s/^\s+|\s+$//g;
                push @authors, $au if $au;
            }
            my $link_id = "link_".$prefix.($link_max_id++);

            my $sno = $ref_id =~ /(\d+)/ ? $1 : $ref_id;
            my $author_string = join(', ', @authors);
            if (defined $year) {
                if ($ref_content =~ /<etal[^>]*>\s*et\s+al\s*\.\s*<\/etal>/i) {
                    $author_string .= ' et al.';
                }
                $author_string .= sprintf(
                    ' <bibcit rid="%s" title="bibcit" href="#" contenteditable="false" id="%s" sno="%s">%s</bibcit>',
                    $ref_id, $link_id, $sno, $year
                );
            }

            $authors{$ref_id} = $author_string if $author_string;
        }
    }
    
    return \%authors;
}

sub get_max_link_id {
    my ($xml) = @_;
    my $max_id = 0;
    my $prefix = "";
    while ($xml =~ /(<bibcit[^<>]*link_([a-z][0-9][a-z])(\d+)[^<>]*>)/gi) {
        $prefix = $2;
        my $id_num = $3;
        $max_id = $id_num if $id_num > $max_id;
    }
    return ($max_id, $prefix);
}

# Process figcit ids
sub process_figcit_ids {
    my ($content, $ids_str) = @_;
    my @apt_ids = split /,/, $ids_str;
    my @sno_ids;
    
    foreach my $apt_id (@apt_ids) {
        if ($content =~ /<fig[^>]*?id="\Q$apt_id\E"[^<>]*?>\s*<ti[^<>]*?sno="(\d+)"[^<>]*?>/) {
            push @sno_ids, $1;
        }
    }
    
    if (@sno_ids && $sno_ids[0] =~ /^\d+$/) {
        return sort { $a <=> $b } @sno_ids;
    } else {
        return sort @sno_ids;
    }
}

# Extract fig info
sub extract_fig_info {
    my ($content, @sno_ids) = @_;
    my %fig_info;
    
    foreach my $sno (@sno_ids) {
        if ($content =~ /<fig\s+[^<>]*?id="([^<>]*?)"[^<>]*?>\s*<ti\s+[^<>]*?sno="\Q$sno\E"[^>]*?>/) {
            my $apt_id = $1;
            $fig_info{$sno}{apt_id} = $apt_id;
            $fig_info{$sno}{sno} = $sno;
        } else {
            warn "Warning: Could not find fig entry with sno=$sno\n";
        }
    }
    return %fig_info;
}

# Generate figcit tags
sub generate_figcit_tags {
    my ($ranges, $fig_info, $max_figcit_id_ref, $max_apt_id_ref, $xml_content) = @_;
    my @figcit_tags;

    my $captured_text = '';
    my $prefix = '';
    if ($xml_content && $xml_content =~ m{<figcit[^<>]*>([^<>]*?)\d+<\/figcit>}i) {
        my $full_match = $&;
        $captured_text = $1 || '';
        if($full_match =~ /prefix="([^<>]*?)"/i) {
            $prefix = $1 || "Figure ";
        }
        else {
            $prefix = "Figure";
        }
        $captured_text =~ s/\s+$/ /;
    }
    foreach my $range (@$ranges) {
        my @ids = @$range;
        my @apt_ids = map { $fig_info->{$_}{apt_id} } @ids;
        my @snos = map { $fig_info->{$_}{sno} } @ids;

        my $range_text = @ids > 1 ? "$ids[0]-$ids[-1]" : $ids[0];

        my $display_text = $captured_text ? "$captured_text$range_text" : $range_text;

        my $figcit = qq($prefix <figcit rid=") . join(" ", @apt_ids) .
                     qq(" title="figcit" href="#" contenteditable="false" ) .
                     qq(id="figcit_$$max_figcit_id_ref" ) .
                     qq(sno=") . join(" ", @snos) .
                     qq(" apt_id="$$max_apt_id_ref">$display_text</figcit>);

        push @figcit_tags, $figcit;
        $$max_figcit_id_ref++;
        $$max_apt_id_ref++;
    }

    return @figcit_tags;
}

# Print figcit results
sub print_figcits_results {
    my ($figcit_tags_ref, $content, $missing_ids_ref) = @_;
    my $output = join("\n", @$figcit_tags_ref);
    my $num_tags = scalar @$figcit_tags_ref;
    
    my $parens_pattern = qr/(\(Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?rid[^>]*>.*?<\/figcit>.*?\))/;
    my $brackets_pattern = qr/(\[Fig(?:s|ure)?\.?\s*<figcit\b[^>]*?rid[^>]*>.*?<\/figcit>.*?\))/;

    if ($content =~ $parens_pattern || $content =~ $brackets_pattern ) {
        my $matched = $&;
        my $content_inside = $1;
        my $open_char = substr($matched, 0, 1);
        my $close_char = $open_char eq '[' ? ']' : ')';
        
        my $separator = '';
        if ($content_inside =~ /<figcit\b[^>]*?>[^<>]*<\/figcit>(\s*[,;]?)\s*<figcit/) {
            $separator = $1.' ' || ', ';
        }
        else {
            $separator = ', ';
        }

        $output = $open_char . 
                 join($separator, @$figcit_tags_ref) . 
                 $close_char;
    }
    
    $output =~ s/\(\)|\[\]//g;

    my $json_output = {
        message => "",
        result => $output,
        status => "success",
        timestamp => scalar localtime
    };

    if(@$missing_ids_ref) {
        $json_output->{message} = "Warning: The following figure IDs were not found: " . join(", ", @$missing_ids_ref);
        $json_output->{missing_ids} = $missing_ids_ref;
    }

    $json_output->{result} = restore_unicode($json_output->{result});   
    print to_json($json_output, {utf8 => 1, pretty => 1, canonical => 1}) . "\n";
}

# Process a single TBCIT reference
sub process_single_tbcit {
    my ($xml_content, $tbcit_id, $max_apt_id_ref) = @_;

    if ($xml_content =~ /(<table(?:g)?[^>]*?id="\Q$tbcit_id\E"[^>]*>\s*<ti[^<>]*?>)/ms) {
        my $tableg_tag = $1;
        
        my ($prefix, $sno, $suffix) = ("", "", "");
        $prefix = $1 if $tableg_tag =~ /prefix="([^"]*?)"/;
        $sno = $1 if $tableg_tag =~ /sno="([^"]*?)"/;
        $suffix = $1 if $tableg_tag =~ /suffix="([^"]*?)"/;
        
        $$max_apt_id_ref++;
        my $tbcit_content = "$sno";
        $tbcit_content =~ s/\s+/ /g;
        
        my $tbcit_tag = qq{$prefix <tbcit class="noneditable" href="#$tbcit_id" rid="$tbcit_id" } .
                       qq{type="arabic" apt_id="$$max_apt_id_ref" id="tbcit_$$max_apt_id_ref" } .
                       qq{contenteditable="false" data-tor-href="#">$tbcit_content</tbcit>};
        $tbcit_tag =~ s/\s+/ /g;
        return { found => 1, tag => $tbcit_tag };
    }
    
    return { found => 0 };
}

# Generate TBCIT JSON response
sub generate_tbcit_response {
    my ($found_ref, $missing_ref) = @_;
    
    my $message = "";
    $message = "Warning: The following reference IDs were not found: " . join(', ', @$missing_ref) if @$missing_ref;

    my %response = (
        result    => join(", ", @$found_ref),
        status    => "success",
        timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime),
        message   => $message
    );

    $response{missing_ids} = $missing_ref if @$missing_ref;
    
    return to_json(\%response, { pretty => 1, utf8 => 1 });
}

# Restore original characters before JSON output
sub restore_unicode {
    my ($text) = @_;
    while (my ($name, $char) = each %char_map) {
        my $html_entity = sprintf("&#%d;", ord($char));
        $text =~ s/$name/$html_entity/g;
    }
    return $text;
}

# Process section IDs and find/create citations
sub process_section_ids {
    my ($content, $ids_str, $max_apt_id_ref) = @_;
    my @ids = split(/,/, $ids_str);
    my (@found_citations, @missing_ids);
    
    foreach my $sect_id (@ids) {
        $sect_id =~ s/^\s+|\s+$//g;
        my $found = 0;
        my $section_prefix = "";
        
        if ($content =~ /(Sec\.|Section)?\s*(<seccit[^>]*rid="\Q$sect_id\E"[^>]*>.*?<\/seccit>)/i) {
            $section_prefix = $1 || "";
            push @found_citations, "$section_prefix $2";
            $found = 1;
            next;
        }

        if ($content =~ /<sect\d+\s+[^>]*?apt_id="\Q$sect_id\E"[^>]*>\s*<ti[^>]*?\bsno="([^"]*)"[^>]*>/s) {
            my $sno = $1;
            my $sect_match = $&;
            my $sect_apt_id = $sect_id;
            $sect_apt_id = $1 if $sect_match =~ /apt_id="([^"]*)"/;
            
            $$max_apt_id_ref++;
            my $new_seccit = qq{<seccit rid="$sect_apt_id" title="seccit" href="#" contenteditable="false" id="seccit_$$max_apt_id_ref" apt_id="$$max_apt_id_ref">$sno</seccit>};
            push @found_citations, $section_prefix ? "$section_prefix $new_seccit" : $new_seccit;
            $found = 1;
        }
        
        push @missing_ids, $sect_id unless $found;
    }
    
    return (\@found_citations, \@missing_ids);
}

# Process found citations and create ranges
sub process_section_citations {
    my ($found_citations, $missing_ids, $max_apt_id) = @_;
    my @sections;
    
    foreach my $citation (@$found_citations) {
        if ($citation =~ /(Sec\.|Section)?\s*<seccit[^>]*?rid="([^<>]*?)"[^>]*(?:apt_id="([^"]*?)")?[^>]*?>([^<]+)<\/seccit>/) {
            push @sections, {
                prefix => $1 || "",
                rid => $2, 
                apt_id => $3 || ++$max_apt_id, 
                num => $4 
            };
        }
    }
    
    my @output;
    my %num_to_section = map { $_->{num} => $_ } @sections;
    my @section_numbers = map { $_->{num} } @sections;
    my @ranges = find_ranges(@section_numbers);

    foreach my $range (@ranges) {
        if ($range =~ /^(\d+)-(\d+)$/) {
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
        } elsif (exists $num_to_section{$range}) {
            my $section = $num_to_section{$range};
            $max_apt_id++;
            my $prefix = $section->{prefix} || 'Section';
            push @output, qq{$prefix <seccit rid="$section->{rid}" title="seccit" href="#$section->{rid}" contenteditable="false" id="seccit_$max_apt_id" apt_id="$max_apt_id" data-tor-href="#$section->{rid}">$range</seccit>};
        }
    }
    
    return {
        message => @$missing_ids ? "Some section IDs not found: " . join(', ', @$missing_ids) : "",
        result => join(', ', @output),
        status => "success",
        missing_ids => $missing_ids,
        timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime)
    };
}

# Find ranges in section numbers
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
                push @result, $start == $prev ? $start : "$start-$prev";
                $start = $prev = $whole[$i];
            }
        }
        push @result, $start == $prev ? $start : "$start-$prev";
    }
    
    push @result, sort { $a <=> $b } @decimals;
    push @result, sort { $a cmp $b } @alpha_numeric;
    
    return @result;
}

# Find the maximum link number in the content
sub find_max_link_number {
    my ($content) = @_;
    my $max_link_num = 0;
    my $prefix = "";
    while ($content =~ /id="link_([a-z0-9]+)"/gi) {
        my $link_id = $1;
        if ($link_id =~ /([a-z][0-9][a-z]*)(\d+)$/i) {
            $prefix = $1;
            $max_link_num = $2 if $2 > $max_link_num;
        }
    }
    return ($prefix, $max_link_num);
}

# Try direct match for appcit ID
sub try_direct_match {
    my ($content_ref, $result_ref, $prefix_ref, $max_link_num_ref, $appcit_id, $tag_name) = @_;
    
    if ($$content_ref =~ /($appendix_patterns->{$tag_name}<$tag_name[^<>]*?rid="\Q$appcit_id\E"[^<>]*?)>([^<>]*)(<\/$tag_name>\)?)/i) {
        my ($before, $content_part, $after) = ($1, $2, $3);
        $before =~ s/\bid="[^<>"]*"//;
        $$max_link_num_ref++;
        my $new_id = "link_" . $$prefix_ref . $$max_link_num_ref;
        my $new_appcit = "$before id=\"$new_id\">$content_part$after";
        push @$result_ref, $new_appcit;
        return 1;
    }
    
    return 0;
}

# Try pattern matching for different citation types
sub try_pattern_matching {
    my ($content_ref, $result_ref, $prefix_ref, $max_link_num_ref, $appcit_id, $tag_name) = @_;
    
    my $mapping = {
        appcit => "app",
        figcita => "figa",
        tbcita => "tablega"
    };
    
   
    foreach my $pattern (keys %$mapping) {
        my $tag = $mapping->{$pattern};
        if ($$content_ref =~ /(<$tag[^<>]*?id="\Q$appcit_id\E"[^<>]*?>\s*<ti[^<>]*?>[^<>]*)/i) {
            my $app_content = $1;
            my $sno = '';
            
            if ($app_content =~ /sno="([^"]*)"/) {
                $sno = $1;
            } 
            elsif ($app_content =~ /APPENDIX(?:\b|\s)([A-Za-z])\b/i) {
                $sno = $1;
            }
            
            $$max_link_num_ref++;
            my $new_appcit = qq{<$tag_name rid="$appcit_id" title="appcit" href="#" contenteditable="false" id="link_$$prefix_ref$$max_link_num_ref">$sno</$tag_name>};
            push @$result_ref, $new_appcit;
            return 1;
        }
    }
    
    return 0;
}

# Generate the final result
sub generate_appcit_result {
    my ($result_appcits_ref, $missing_ids_ref) = @_;

    my $final_citations = "";
    if(scalar @$result_appcits_ref > 0){
        $final_citations = join(", ", @$result_appcits_ref);
        $final_citations =~ s/\s+/ /g;
    }    
    my $result = {
        timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime),
        message   => "",
        status    => "success",
        result    => $final_citations
    };

    if (@$missing_ids_ref) {
        $result->{message} = "Missing appcit IDs: " . join(", ", @$missing_ids_ref);
        $result->{missing_ids} = $missing_ids_ref;
    }

    print JSON->new->pretty->encode($result);
}

# Print help
sub print_help {
    print <<"USAGE";
Citation Matcher v$CONFIG->{version}

Usage: $0 <xml_file> <bibcit_id1[,bibcit_id2,...]> <tag_name>

Required Arguments:
  xml_file              Path to the XML file containing citations
  bibcit_ids            Comma-separated list of citation IDs (e.g., bib1,bib2,bib3)
  tag_name              Type of citation to process: 'bibcit' or 'figcit'

Options:
  -h, --help            Show this help message

Examples:
  $0 input.xml bib1,bib2,bib3 bibcit
  $0 input.xml fig1,fig2,fig3 figcit
  $0 input.xml tbl1,tbl2,tbl3 tbcit
  $0 input.xml fig1,fig2,fig3 figcita
  $0 input.xml tbl1,tbl2,tbl3 tbcita
  $0 input.xml sec10,sec20,sec30 appcit
USAGE
}