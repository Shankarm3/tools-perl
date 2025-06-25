#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use POSIX qw(strftime);

# Main function to handle command line execution
sub main {
    if (@_ != 3) {
        die "Usage: $0 <xml_file> <comma_separated_tbcit_ids> <tagname>\n";
    }

    my ($xml_file, $tbcit_ids_str, $tagname) = @_;
    process_tbcit_references($xml_file, $tbcit_ids_str, $tagname);
    exit 0;
}

# Main processing function that can be called from other modules
sub process_tbcit_references {
    my ($xml_file, $tbcit_ids_str, $tagname) = @_;

    my @tbcit_ids = split(/,/, $tbcit_ids_str);
    my $xml_content = read_xml_file($xml_file);
    my $max_apt_id = find_max_id($xml_content, 'apt_id="(\d+)"');

    my @found_results;
    my @missing_ids;

    foreach my $tbcit_id (@tbcit_ids) {
        $tbcit_id =~ s/^\s+|\s+$//g;
        next unless $tbcit_id;
        
        my $result = process_single_tbcit($xml_content, $tbcit_id, \$max_apt_id);
        if ($result->{found}) {
            push @found_results, $result->{tag};
        } else {
            push @missing_ids, $tbcit_id;
        }
    }

    my $result = generate_response(\@found_results, \@missing_ids);
    print $result
}

# Read XML file with error handling
sub read_xml_file {
    my ($file) = @_;
    open(my $fh, '<:encoding(UTF-8)', $file) or die "Could not open file '$file': $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

# Process a single TBCIT reference
sub process_single_tbcit {
    my ($xml_content, $tbcit_id, $max_apt_id_ref) = @_;

    if ($xml_content =~ /(<tableg[^>]*?id="\Q$tbcit_id\E"[^>]*>\s*<ti[^<>]*?>)/ms) {
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
        
        return { found => 1, tag => $tbcit_tag };
    }
    
    return { found => 0 };
}

# Generate JSON response
sub generate_response {
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

# Find maximum ID in content matching pattern
sub find_max_id {
    my ($content, $pattern) = @_;
    my $max_id = 0;
    while ($content =~ /$pattern/g) {
        $max_id = $1 if $1 > $max_id;
    }
    return $max_id + 1;
}

# Call main if this script is executed directly
main(@ARGV) unless caller();