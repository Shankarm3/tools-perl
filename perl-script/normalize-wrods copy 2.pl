use strict;
use warnings;
use utf8;
use JSON;
use open qw(:std :utf8);

# Read the entire XML content
my $xml = do {
    local $/;
    open my $fh, '<', 'input.xml' or die "Can't open file: $!";
    <$fh>;
};
$xml =~ s/\r\n/\n/g;

# Normalized words to search
my @normalized_words = ('x axis', 'broad band');

# Define separators and their types
my %separator_info = (
    '-' => { type => 'hyphen', display => '-' },
    '&ndash;' => { type => 'hyphen', display => '&ndash;' },
    '&mdash;' => { type => 'hyphen', display => '&mdash;' },
    '--' => { type => 'hyphen', display => '--' },
    "-\\s*\\n\\s*" => { type => 'hyphen', display => '-\\n' },
    ' ' => { type => 'space', display => ' ' },
    '&nbsp;' => { type => 'space', display => '&nbsp;' },
    '&nbsp;&nbsp;' => { type => 'space', display => '&nbsp;&nbsp;' },
    '&#x00A0;' => { type => 'space', display => '&#x00A0;' },
    '&#160;' => { type => 'space', display => '&#160;' },
    '&#xa0;' => { type => 'space', display => '&#xa0;' },
    '&#xA0;' => { type => 'space', display => '&#xA0;' },
);

my %results;
foreach my $norm (@normalized_words) {
    my ($first, $second) = split /\s+/, $norm, 2;
    my %counts = (hyphen => 0, space => 0);
    my %operator_counts;
    
    foreach my $sep (keys %separator_info) {
        my $form = $first . $sep . $second;
        my $pattern = $sep =~ /\\n/ ? $form : quotemeta($form);
        my $count = 0;
        
        my $xml_working = $xml;
        while ($xml_working =~ /$pattern/ig) {
            $count++;
            substr($xml_working, $-[0], $+[0] - $-[0], '');
            pos($xml_working) = 0;
        }
        
        if ($count > 0) {
            my $type = $separator_info{$sep}{type};
            my $display = $separator_info{$sep}{display};
            $counts{$type} += $count;
            $operator_counts{$display} = $count;
        }
    }
    
    # Generate suggestion
    my $suggestion = $counts{space} > $counts{hyphen} 
        ? "$first $second $first-$second" 
        : "$first-$second $first $second";
    
    $results{$norm} = {
        hyphen => $counts{hyphen},
        space => $counts{space},
        operators => \%operator_counts,
        suggestion => $suggestion
    };
}

# Output final JSON
my $json = JSON->new->pretty->canonical->encode(\%results);
print $json;