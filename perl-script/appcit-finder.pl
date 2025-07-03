#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use POSIX qw(strftime);
use utf8;
use Data::Dumper;
use open ':std', ':encoding(UTF-8)';

our $patterns = {
    appcit => qr{\(?(?:Appendix|App)\.?\s*},
    figcita => qr{\(?(?:Fig|Figure)\.?\s*},
    tbcita => qr{\(?(?:Tab|Table)\.?\s*}
};

# Main function
sub main {
    my ($filename, $appcit_ids_str, $tag_name) = @_;
    
    die "Usage: $0 <filename> <appcit_id1> [<appcit_id2> ...]\n" unless $filename;
    die "Please provide comma-separated appcit IDs\n" unless $appcit_ids_str;
    die "Please provide tag name\n" unless $tag_name;
    
    my @appcit_ids = split(/,/, $appcit_ids_str);
    my $content = read_file_content($filename);
    
    my ($result_appcits, $missing_ids, $max_link_num) = process_appcits_figcita_tbcita($content, \@appcit_ids, $tag_name);
    return generate_result($result_appcits, $missing_ids);
}

# Read and preprocess file content
sub read_file_content {
    my ($filename) = @_;
    
    open(my $fh, '<', $filename) or die "Could not open file '$filename': $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    $content =~ s/\xA0/ /g;
    $content =~ s/\s+/ /g;
    return $content;
}

# Process appcit IDs and find matches
sub process_appcits_figcita_tbcita {
    my ($content, $appcit_ids_ref, $tag_name) = @_;
    my @appcit_ids = @$appcit_ids_ref;
    my @result_appcits;
    my @missing_ids;
    
    my $max_link_num = find_max_link_number($content);
    
    foreach my $appcit_id (@appcit_ids) {
        my $found = 0;
        
        $found = try_direct_match(\$content, \@result_appcits, \$max_link_num, $appcit_id, $tag_name);
        
        unless ($found) {
            $found = try_pattern_matching(\$content, \@result_appcits, \$max_link_num, $appcit_id, $tag_name);
        }
        
        push @missing_ids, $appcit_id unless $found;
    }
    
    return (\@result_appcits, \@missing_ids, $max_link_num);
}

# Find the maximum link number in the content
sub find_max_link_number {
    my ($content) = @_;
    my $max_link_num = 0;
    
    while ($content =~ /id="link_([a-z0-9]+)"/gi) {
        my $link_id = $1;
        if ($link_id =~ /[a-z0-9][a-z]*(\d+)$/i) {
            $max_link_num = $1 if $1 > $max_link_num;
        }
    }
    return $max_link_num;
}

# Try direct match for appcit ID
sub try_direct_match {
    my ($content_ref, $result_ref, $max_link_num_ref, $appcit_id, $tag_name) = @_;
    
    if ($$content_ref =~ /($patterns->{$tag_name}<$tag_name[^<>]*?rid="\Q$appcit_id\E"[^<>]*?)>([^<>]*)(<\/$tag_name>\)?)/i) {
        my ($before, $content_part, $after) = ($1, $2, $3);
        $before =~ s/\bid="[^<>"]*"//;
        $$max_link_num_ref++;
        my $new_id = "link_" . $$max_link_num_ref;
        my $new_appcit = "$before id=\"$new_id\">$content_part$after";
        push @$result_ref, $new_appcit;
        return 1;
    }
    
    return 0;
}

# Try pattern matching for different citation types
sub try_pattern_matching {
    my ($content_ref, $result_ref, $max_link_num_ref, $appcit_id, $tag_name) = @_;
    
    my $mapping = {
        appcit => "app",
        figcita => "figa",
        tbcita => "tablega"
    };
    
   
    foreach my $pattern (keys %$mapping) {
        my $tag = $mapping->{$pattern};
        if ($$content_ref =~ /(<$tag[^<>]*?id="\Q$appcit_id\E"[^<>]*?>\s*<ti[^<>]*?>[^<>]*)/i) {
            my $app_content = $1;
            print("app_content ======> $app_content\n");
            my $sno = '';
            
            if ($app_content =~ /sno="([^"]*)"/) {
                $sno = $1;
            } 
            elsif ($app_content =~ /APPENDIX(?:\b|\s)([A-Za-z])\b/i) {
                $sno = $1;
            }
            
            $$max_link_num_ref++;
            my $new_appcit = qq{<$tag_name rid="$appcit_id" title="appcit" href="#" contenteditable="false" id="link_$$max_link_num_ref">$sno</$tag_name>};
            push @$result_ref, $new_appcit;
            return 1;
        }
    }
    
    return 0;
}

# Generate the final result
sub generate_result {
    my ($result_appcits_ref, $missing_ids_ref) = @_;
    
    my $result = {
        timestamp => strftime("%a %b %d %H:%M:%S %Y", localtime),
        message   => "",
        status    => @$missing_ids_ref ? "partial" : "success",
        result    => join(", ", @$result_appcits_ref)
    };

    if (@$missing_ids_ref) {
        $result->{message} = "Missing appcit IDs: " . join(", ", @$missing_ids_ref);
        $result->{missing_ids} = $missing_ids_ref;
    }

    return $result;
}

# Script entry point
if (!caller) {
    my $filename = shift or die "Usage: $0 <filename> <appcit_id1> [<appcit_id2> ...]\n";
    my $appcit_ids_str = shift or die "Please provide comma-separated appcit IDs\n";
    my $tag_name = shift or die "Please provide tag name\n";
    
    my $result = main($filename, $appcit_ids_str, $tag_name);
    print JSON->new->pretty->encode($result);

} 