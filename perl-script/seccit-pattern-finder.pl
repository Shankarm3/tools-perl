#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use JSON;
use POSIX 'strftime';
use Data::Dumper;

# Main function
sub main {
    my ($xml_file, $ids_str, $tag_name) = @ARGV;
    die "Usage: $0 <xml_file> <comma_separated_ids> <tag_name>\n" unless @ARGV == 3;
    
    my $content = read_xml_file($xml_file);
    my $max_apt_id = find_max_apt_id($content);
    my ($found_citations, $missing_ids) = process_section_ids($content, $ids_str, \$max_apt_id);
    my $result = process_section_citations($found_citations, $missing_ids, $max_apt_id);
    print JSON->new->pretty(1)->encode($result);
}

# Read and preprocess XML file
sub read_xml_file {
    my ($xml_file) = @_;
    open(my $fh, '<:encoding(UTF-8)', $xml_file) or die "Could not open file '$xml_file': $!\n";
    my $content = do { local $/; <$fh> };
    $content =~ s/\xA0/ /g;
    close $fh;
    return $content;
}

# Find maximum apt_id in the document
sub find_max_apt_id {
    my ($content) = @_;
    my $max_apt_id = 0;
    while ($content =~ /apt_id="(\d+)"/g) {
        $max_apt_id = $1 if $1 > $max_apt_id;
    }
    return $max_apt_id;
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
            push @output, qq{$prefix <seccit rid="$section->{rid}" title="seccit" href="#$section->{rid}" contenteditable="false" id="seccit_$max_apt_id" apt_id="$max_apt_id">$range</seccit>};
        }
    }
    
    return {
        message => @$missing_ids ? "Some section IDs not found: " . join(', ', @$missing_ids) : "",
        result => join(', ', @output),
        status => @$missing_ids ? "partial" : "success",
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

main(@ARGV);