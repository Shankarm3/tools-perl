#!/usr/bin/perl
use strict;
use warnings;
use Text::Unidecode;

sub read_xml {
    my ($file) = @_;
    open my $fh, '<:encoding(UTF-8)', $file or die "Cannot open $file: $!";
    local $/;
    my $xml = <$fh>;
    close $fh;
    $xml = unidecode($xml);
    $xml =~ s/\&amp;/\&/g;
    $xml =~ s/\xA0/ /g;
    return $xml;
}

sub build_patterns {
    my ($bibcit_id) = @_;
    my $bibcit_pattern = qr{
        <bibcit\b
        [^>]*?
        rid\s*=\s*["']\Q$bibcit_id\E["']
        [^>]*?>
        .*?
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

sub classify_pattern_type {
    my ($match) = @_;
    return 'parens'        if $match =~ /^\(.*<bibcit.*<\/bibcit>\)$/;
    return 'author_parens' if $match =~ /^[^()]*\(<bibcit.*<\/bibcit>\)$/;
    return 'no_parens'     if $match =~ /^[^()]*<bibcit.*<\/bibcit>$/;
    return 'other';
}

sub find_most_common_type {
    my (%pattern_type_count) = @_;
    return (sort { $pattern_type_count{$b} <=> $pattern_type_count{$a} } keys %pattern_type_count)[0];
}

sub main {
    die "Usage: $0 <xml_file> <bibcit_id>\n" unless @ARGV == 2;
    my ($xml_file, $bibcit_id) = @ARGV;

    my $xml = read_xml($xml_file);
    my @patterns = build_patterns($bibcit_id);

    my $xml_copy = $xml;
    my (%full_match_count, %pattern_type_count, %pattern_type_matches);

    for my $pat (@patterns) {
        while ($xml_copy =~ /$pat/g) {
            my $match = $&;
            print("Found match: $match\n");
            $match =~ s/^\s+|\s+$//g;
            $full_match_count{$match}++;
            my $type = classify_pattern_type($match);
            $pattern_type_count{$type}++;
            push @{$pattern_type_matches{$type}}, $match;
            $xml_copy =~ s///;
            pos($xml_copy) = 0;
        }
    }

    my $most_common_type = find_most_common_type(%pattern_type_count);

    # Print all matched patterns
    if (%full_match_count) {
        print "All matched patterns for bibcit id '$bibcit_id':\n";
        for my $m (sort keys %full_match_count) {
           print "$m\n";
        }
    }

    # Print only one (the first, sorted) match from the most common pattern type
    if ($most_common_type && @{$pattern_type_matches{$most_common_type}}) {
        my @sorted = sort @{$pattern_type_matches{$most_common_type}};
        #print "$sorted[0]\n";
    } else {
        print "No patterns found for bibcit id '$bibcit_id'.\n";
    }
}

main();