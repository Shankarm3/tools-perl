#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use Data::Dumper;

my %special_chars;
my $file_count = 0;

# Process only first 2 XML files
find(\&process_file, '.');

# Print results
print "Unique special characters found in author names:\n";
my $unique_chars = {};
foreach my $char (sort keys %special_chars) {
    my $code = sprintf("U+%04X", ord($char));
    if($unique_chars->{$code}) {
        $unique_chars->{$code} += 1;
    } else {
        $unique_chars->{$code} = 1;
    }
}
foreach my $code (sort keys %{$unique_chars}) {
    print "$code\n";
}
sub process_file {
    # return if $file_count >= 2;  # Stop after processing 2 files
    
    my $file = $File::Find::name;
    return unless $file =~ /\.xml?$/i;  # Only process XML files
    
    $file_count++;
    
    open(my $fh, '<:encoding(UTF-8)', $file) or do {
        warn "Could not open $file: $!\n";
        return;
    };
    
    local $/;  # Slurp mode
    my $content = <$fh>;
    close $fh;
    
    # Find all <ref> sections
    while ($content =~ /<ref[^<>]*>(.*?)<\/ref>/gs) {
        my $ref_content = $1;
        while ($ref_content =~ /<s[^>]*>(.*?)<\/s>\s*<f[^>]*>(.*?)<\/f>/gs) {      
            my ($surname, $firstname) = ($1, $2);
            process_name($surname, $file);
            process_name($firstname, $file);
            $ref_content =~ s/\Q$&\E//; 
        }
    }
}

sub process_name {
    my ($name, $file) = @_;
    $name =~ s/[a-zA-Z&;\-_.]+//g;
    if($name ne "") {
        push @{$special_chars{$name} //= []}, $file;
    }

}