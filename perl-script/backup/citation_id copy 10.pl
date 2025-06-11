#!/usr/bin/perl
use strict;
use warnings;
use Text::Unidecode;
use Data::Dumper;

my $global_patterns = {
    'pat-with-and' => '\\((?:[^()]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>[;,]?\\s*)*\\s*and\\s+[^\\(\\)<>]*?<bibcit\\b[^>]*>[^<>]*<\\/bibcit>\\)',
    'pat1-with-bracket' => '\\((?:e\\.g\\.\\s*(?:see)?)?([^<>\\)\\(]*?<bibcit\\b[^>]*>[^<>]*?<\\/bibcit>[,;]?)\\)',
    'pat2-with-bracket' => '\\((?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)\\)',
    'pat3-without-bracket' => '(?:[A-Z][a-zA-Z\\-\\\']+(?:\\s+et\\s+al\\.)?\\s*<bibcit\\b[^>]*?>[^<>]*<\\/bibcit>\\s*[;,]?\\s*)'
};


my $most_common_patterns_list = [];
my $total_bibcit_ids = 0;

sub read_xml {
    my ($file) = @_;
    open my $fh, '<:encoding(UTF-8)', $file or die "Cannot open $file: $!";
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

sub classify_pattern_type {
    my ($match) = @_;
    return 'parens'        if $match =~ /^\([^<]*<bibcit[^<]*>[^<>]*<\/bibcit>\)$/;
    return 'author_parens' if $match =~ /^[^()]*\(<bibcit[^<]*>[^<>]*<\/bibcit>\)$/;
    return 'no_parens'     if $match =~ /^[^()]*<bibcit[^<]*>[^<>]*<\/bibcit>$/;
    return 'other';
}

sub find_most_common_type {
    my (%pattern_type_count) = @_;
    return (sort { $pattern_type_count{$b} <=> $pattern_type_count{$a} } keys %pattern_type_count)[0];
}

sub process_bibcit_id {
    my ($xml, $bibcit_id) = @_;

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
        print "All matched patterns for bibcit id '$bibcit_id':\n";
        for my $m (sort keys %full_match_count) {
           print "$m\n";
        }
    }

    my $most_common_pattern = '';
    if ($most_common_type && @{$pattern_type_matches{$most_common_type}}) {
        my @sorted = sort @{$pattern_type_matches{$most_common_type}};
        print "Most common pattern type: $most_common_type\n";
        print "$sorted[0]\n";
        $most_common_pattern = $sorted[0];
    } else {
        print "No patterns found for bibcit id '$bibcit_id'.\n";
    }
    print "\n";
    return $most_common_pattern;
}

sub process_most_common_patterns {
    my ($xml, $patterns_ref) = @_;
    my @patterns = @$patterns_ref;
    log_info("Processing most common patterns... @patterns");
    my $max_pattern_found = undef;
    foreach my $pattern (@patterns) {
        if ($pattern) {
            my $type = classify_pattern_type($pattern);
            print "Pattern: $pattern\n";
            print "Type: $type\n";
        } else {
            print "No pattern found.\n";
        }
    }
    my $pattern_count = scalar @patterns;
    $total_bibcit_ids = $pattern_count;
    if ($pattern_count > 0) {
        print "Total patterns processed: $pattern_count\n";
        $max_pattern_found = find_matching_patterns_source_xml($xml, \@patterns) || '';
        print("Max pattern found: ", $max_pattern_found,"\n");
        return $max_pattern_found;
    } else {
        print "No patterns to process.\n";
    }
    return "";
}

sub find_matching_patterns_source_xml {
    my ($xml, $patterns) = @_;
    my $regex_pattern = get_regex_pattern($patterns);
    log_info("Regex pattern for source XML: @{$regex_pattern}\n");
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
                log_info("skipping this isntance.....");
                next;
            }
            if ($pattern_hash->{$regex}) {
                $pattern_hash->{$regex}++;
            } else {
                $pattern_hash->{$regex} = 1;
            }
            my $match = $&;
            $match =~ s/^\s+|\s+$//g;
            $count++;
            print("Matched pattern in source XML: Count => $count, $match\n\n");
            $xml =~ s/\Q$match\E//;
        }
        if( $i == 3) {
            $xml =~ s/$replace_pattern//g;
            next;
        }
    }

    print Dumper($pattern_hash);
    my @sorted_keys = sort { $pattern_hash->{$b} <=> $pattern_hash->{$a} } keys %$pattern_hash;
    print Dumper(@sorted_keys);
    log_info("Sorted keys: @sorted_keys\n");
    return @sorted_keys[0] if $count > 0;
    return undef;
}

sub get_regex_pattern {
    my ($patterns) = @_;
    return unless @$patterns;
    my $pattern = '';
    my $pattern_count = scalar @$patterns;
    if ($pattern_count > 0) {
        $pattern = [
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
        return $pattern;
    }
}

sub log_info {
    my ($message) = @_;
    print STDERR "[INFO] $message\n";
}

sub main {
    die "Usage: $0 <xml_file> <bibcit_id1[,bibcit_id2,...]>\n" unless @ARGV == 2;
    my ($xml_file, $bibcit_ids) = @ARGV;

    my $xml = read_xml($xml_file);
    my $xml_copy = $xml;
    my @ids = map { s/^\s+|\s+$//gr } split /,/, $bibcit_ids;
    my @most_common_patterns;

    for my $bibcit_id (@ids) {
        my $pattern = process_bibcit_id($xml, $bibcit_id);
        push @most_common_patterns, $pattern if $pattern;
    }

    my $pattern_found = process_most_common_patterns($xml_copy, \@most_common_patterns);
    $pattern_found =~ s/{\d+}//g if $pattern_found;
    $pattern_found =~ s/^\(\?\^ix:\s*|\s*\)$//gs if $pattern_found;

    foreach my $key (keys %{$global_patterns}) {
        log_info("Checking pattern===> $key");
        log_info("Global pattern=====> $global_patterns->{$key}");
        if ($pattern_found && $pattern_found eq $global_patterns->{$key}) {
            log_info("Pattern type: $key\n");
            print "(", join('; ', @most_common_patterns), ")\n";
            last;
        }
    }
}

main();