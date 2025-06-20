#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use JSON;
# Main execution
my ($xml_file, $bibcit_ids_str) = @ARGV;
validate_arguments($xml_file, $bibcit_ids_str);

my $content = read_xml_file($xml_file);
$content =~ s/\s+/ /g;

my @bibcit_ids = process_bibcit_ids($bibcit_ids_str);

my $max_bibcit_id = find_max_id($content, 'id="bibcit_(\d+)"');
my $max_apt_id = find_max_id($content, 'apt_id="(\d+)"');

my $ranges = find_consecutive_ranges(@bibcit_ids);
my %bib_info = extract_bib_info($content, @bibcit_ids);
my @bibcit_tags = generate_bibcit_tags($ranges, \%bib_info, \$max_bibcit_id, \$max_apt_id);

print_results(@bibcit_tags);

# Subroutines
sub validate_arguments {
    my ($file, $ids) = @_;
    die "Usage: $0 <xml_file> <bibcit_id1,bibcit_id2,...>\n" unless $file && $ids;
    die "Error: Cannot read file '$file' or file does not exist.\n" unless -e $file && -r _;
}

sub read_xml_file {
    my $file = shift;
    local $/;
    open(my $fh, '<:encoding(UTF-8)', $file) or die "Could not open file '$file': $!\n";
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub process_bibcit_ids {
    my $ids_str = shift;
    my @ids = split /,/, $ids_str;
    return sort { $a <=> $b } @ids;
}

sub find_max_id {
    my ($content, $pattern) = @_;
    my $max_id = 0;
    while ($content =~ /$pattern/g) {
        $max_id = $1 if $1 > $max_id;
    }
    return $max_id + 1;
}

sub find_consecutive_ranges {
    my @numbers = @_;
    return [] unless @numbers;
    
    my @ranges;
    my @current_range = ($numbers[0]);
    
    for my $i (1..$#numbers) {
        if ($numbers[$i] == $numbers[$i-1] + 1) {
            push @current_range, $numbers[$i];
        } else {
            push @ranges, [@current_range];
            @current_range = ($numbers[$i]);
        }
    }
    push @ranges, \@current_range if @current_range;
    return \@ranges;
}

sub extract_bib_info {
    my ($content, @ids) = @_;
    my %bib_info;
    
    foreach my $id (@ids) {
        if ($content =~ /<bib\s+[^>]*sno="\Q$id\E"[^>]*apt_id="([^"]+)"/) {
            $bib_info{$id}{apt_id} = $1;
            $bib_info{$id}{sno} = $id;
        } else {
            warn "Warning: Could not find bib entry with sno=$id\n";
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
    my @bibcit_tags = @_;
    my $output = join("\n", @bibcit_tags);
    my $num_tags = scalar @bibcit_tags;
    my $brackets_pattern = qr/\[(\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>(\s*[,;]?\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>\s*[,;]?)+)\s*\]/;
    my $parens_pattern = qr/\((\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>(\s*[,;]?\s*<bibcit\b[^>]*?>[^<>]*<\/bibcit>\s*[,;]?)+)\s*\)/;

    if ($content =~ $brackets_pattern || $content =~ $parens_pattern) {
        my $matched = $&;
        my $content_inside = $1;
        my $open_char = substr($matched, 0, 1);
        my $close_char = $open_char eq '[' ? ']' : ')';
        
        my $separator = '';
        if ($content_inside =~ /<bibcit\b[^>]*?>[^<>]*<\/bibcit>(\s*[,;]?)\s*<bibcit/) {
            $separator = $1.' ' || ', '; 
        }

        $output = $open_char . 
                 join($separator, @bibcit_tags) . 
                 $close_char;
    }
    
    my $json_output = {
        message => "",
        result => $output,
        status => "success",
        timestamp => scalar localtime
    };
    print encode_json($json_output) . "\n"; 
}