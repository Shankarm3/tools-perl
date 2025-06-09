use strict;
use warnings;
use utf8;
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

# Separators to try between the split words
my @separators = (
    ' ',         # regular space
    '-',         # hyphen
    '&ndash;',   # ndash entity
    '&mdash;',   # mdash entity
    '--',        # double hyphen
    '&nbsp;',    # non-breaking space
    '&nbsp;&nbsp;', # double non-breaking space
    '&#x00A0;',  # hex non-breaking space
    '&#160;',    # decimal non-breaking space
    '&#xa0;',    # lower hex non-breaking space
    '&#xA0;',    # upper hex non-breaking space
    "-\\s*\\n\\s*", # hyphen + line break (soft hyphenation)
);

print "{\n";
my $xml_working = $xml;
foreach my $norm (@normalized_words) {
    my ($first, $second) = split /\s+/, $norm, 2;
    foreach my $sep (@separators) {
        my $form = $first . $sep . $second;
        my $pattern = $form;
        # For soft line break, already regex, else quote
        $pattern = $sep =~ /\\n/ ? $pattern : quotemeta($form);
        my $count = 0;
        while ($xml_working =~ /$pattern/ig) {
            $count++;
            substr($xml_working, $-[0], $+[0] - $-[0], '');
            pos($xml_working) = 0;
        }
        print qq{    "$form" => $count,\n} if $count > 0;
    }
}
print "}\n";