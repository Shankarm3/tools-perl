#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use POSIX qw(strftime);

# Get command line arguments
my $filename = shift or die "Usage: $0 <filename> <appcit_id1> [<appcit_id2> ...]\n";
my $appcit_ids_str = shift or die "Please provide comma-separated appcit IDs\n";
my $tag_name = shift or die "Please provide tag name\n";

my @appcit_ids = split(/,/, $appcit_ids_str);

# Read the file content
open(my $fh, '<', $filename) or die "Could not open file '$filename': $!\n";
my $content = do { local $/; <$fh> };
close $fh;

my @result_appcits;
my @missing_ids;
my $max_link_num = 0;
my $prefix = '';

while ($content =~ /id="link_([a-z0-9]+)"/gi) {
    my $link_id = $1;
    if($link_id =~ /([a-z0-9]*?)(\d+)$/) {
       $prefix = "link_$1";
       $max_link_num = $2;
    }
}


foreach my $appcit_id (@appcit_ids) {
    my $found = 0;
    
    if ($content =~ /(<$tag_name[^<>]*?rid="\Q$appcit_id\E"[^<>]*?)>([^<>]*)(<\/$tag_name>)/i) {
        my ($before, $content_part, $after) = ($1, $2, $3);
        print("before: $before\n");
        print("content_part: $content_part\n");
        print("after: $after\n");
        $before =~ s/\bid="[^<>"]*"//;
        $max_link_num++;
        my $new_id = $prefix . $max_link_num;
        my $new_appcit = "$before id=\"$new_id\">$content_part$after";
        push @result_appcits, $new_appcit;
        $found = 1;
    }
    
    unless ($found) {
        my $mapping = {
            appcit => "app",
            figcita => "figa",
            tbcita => "tablega"
        };
        
        foreach my $pattern (keys %$mapping) {
            my $tag = $mapping->{$pattern};
            if ($content =~ /(<$tag[^<>]*?id="\Q$appcit_id\E"[^<>]*?>\s*<ti[^<>]*?>)/i) {
                my $app_content = $1;
                my $sno = '';
                if ($app_content =~ /sno="([^"]*)"/) {
                    $sno = $1;
                } 
                elsif ($app_content =~ /APPENDIX\b([A-Z]+)\b/i) {
                    $sno = $1;
                }
                $max_link_num++;
                my $new_appcit = qq{<$tag_name rid="$appcit_id" title="appcit" href="#" contenteditable="false" id="$prefix$max_link_num">$sno</$tag_name>};
                push @result_appcits, $new_appcit;
                $found = 1;
                last;
            }
        }
    }
    
    push @missing_ids, $appcit_id unless $found;
}

my $result = {
    timestamp   => strftime("%a %b %d %H:%M:%S %Y", localtime),
    message     => "",
    status      => @missing_ids ? "partial" : "success",
    result      => join(", ", @result_appcits)
};

if(@missing_ids) {
    $result->{message} = "Missing appcit IDs: " . join(", ", @missing_ids);
    $result->{missing_ids} = \@missing_ids;
}

print JSON->new->pretty->encode($result);