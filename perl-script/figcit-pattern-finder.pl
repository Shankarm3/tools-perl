#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use JSON;

# Main execution
my ($xml_file, $figcit_ids_str) = @ARGV;
validate_arguments($xml_file, $figcit_ids_str);

my $content = read_xml_file($xml_file);
$content =~ s/\s+/ /g;

my @figcit_ids = process_figcit_ids($content, $figcit_ids_str);

my $max_figcit_id = find_max_id($content, 'id="figcit_(\d+)"') || 1000; 
my $max_apt_id = find_max_id($content, 'apt_id="(\d+)"') || 1000;         

my $ranges = find_figcit_consecutive_ranges(@figcit_ids);
my %fig_info = extract_fig_info($content, @figcit_ids);
my @figcit_tags = generate_figcit_tags($ranges, \%fig_info, \$max_figcit_id, \$max_apt_id);

print_figcits_results(\@figcit_tags, $content);

# Subroutines
sub validate_arguments {
    my ($file, $ids) = @_;
    die "Usage: $0 <xml_file> <figcit_id1,figcit_id2,...>\n" unless $file && $ids;
    die "Error: Cannot read file '$file' or file does not exist.\n" unless -e $file && -r _;
}

sub read_xml_file {
    my $file = shift;
    local $/;
    open(my $fh, '<:encoding(UTF-8)', $file) or die "Could not open file '$file': $!\n";
    my $content = <$fh>;
    $content =~ s/&nbsp;/ /g;
    close $fh;
    return $content;
}

sub process_figcit_ids {
    my ($content, $ids_str) = @_;
    my @apt_ids = split /,/, $ids_str;
    my @sno_ids;
    
    foreach my $apt_id (@apt_ids) {
        if ($content =~ /<fig[^>]*?sno="([^"]+)"[^>]*?apt_id="\Q$apt_id\E"/) {
            push @sno_ids, $1;
        } else {
            warn "Warning: Could not find fig entry with apt_id=$apt_id\n";
        }
    }
    
    if (@sno_ids && $sno_ids[0] =~ /^\d+$/) {
        return sort { $a <=> $b } @sno_ids;
    } else {
        return sort @sno_ids;
    }
}

sub find_max_id {
    my ($content, $pattern) = @_;
    my $max_id = 0;
    while ($content =~ /$pattern/g) {
        $max_id = $1 if $1 > $max_id;
    }
    return $max_id + 1;
}

sub find_figcit_consecutive_ranges {
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

sub extract_fig_info {
    my ($content, @sno_ids) = @_;
    my %fig_info;
    
    foreach my $sno (@sno_ids) {
        print("sno================>,", $sno);
        if ($content =~ /<fig\s+[^>]*?sno="\Q$sno\E"[^>]*?apt_id="([^"]+)"/) {
            my $apt_id = $1;
            $fig_info{$sno}{apt_id} = $apt_id;
            $fig_info{$sno}{sno} = $sno;
        } else {
            warn "Warning: Could not find fig entry with sno=$sno\n";
        }
    }
    
    return %fig_info;
}

sub generate_figcit_tags {
    my ($ranges, $fig_info, $max_figcit_id_ref, $max_apt_id_ref) = @_;
    my @figcit_tags;
    
    foreach my $range (@$ranges) {
        my @ids = @$range;
        my @apt_ids = map { $fig_info->{$_}{apt_id} } @ids;
        my @snos = map { $fig_info->{$_}{sno} } @ids;
        
        my $range_text = @ids > 1 ? "$ids[0]-$ids[-1]" : $ids[0];
        
        my $figcit = qq(Fig. <figcit rid=") . join(" ", @apt_ids) . 
                      qq(" title="figcit" href="#" contenteditable="false" ) .
                      qq(id="figcit_$$max_figcit_id_ref" ) .
                      qq(sno=") . join(" ", @snos) . 
                      qq(" apt_id="$$max_apt_id_ref">$range_text</figcit>);
        
        push @figcit_tags, $figcit;
        $$max_figcit_id_ref++;
        $$max_apt_id_ref++;
    }
    
    return @figcit_tags;
}

sub print_figcits_results {
    my ($figcit_tags_ref, $content) = @_;
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

        $output = $open_char . 
                 join($separator, @$figcit_tags_ref) . 
                 $close_char;
    }
    
    my $json_output = {
        message => "",
        result => $output,
        status => "success",
        timestamp => scalar localtime
    };
    
    binmode STDOUT, ':encoding(UTF-8)';
    print to_json($json_output, {utf8 => 1, pretty => 1, canonical => 1}) . "\n";
}