sub normalize_xml {
    my ($xml) = @_;
    
    # Map of Unicode characters to their descriptive names
    my %char_names = (
        "\x{00FD}" => 'yacute',    # ý
        "\x{00E9}" => 'eacute',    # é
        "\x{00E1}" => 'aacute',    # á
        # Add more mappings as needed
    );
    
    my %char_map;
    
    # Find all non-ASCII characters and replace them with descriptive placeholders
    $xml =~ s{([^\x00-\x7F])}{ 
        my $char = $1;
        my $name = $char_names{$char} || sprintf("char_%04X", ord($char));
        my $placeholder = "__${name}__";
        $char_map{$placeholder} = $char;
        $placeholder;
    }ge;
    
    # Apply other normalizations
    $xml =~ s/\&amp;/\&/g;
    $xml =~ s/\&nbsp;/ /g;
    $xml =~ s/\xA0/ /g;
    $xml =~ s/<latex[^<>]*>.*?<\/latex>\s*.\s*//msg;
    $xml =~ s/\s+/ /g;
    
    # Apply unidecode to the rest of the text
    $xml = unidecode($xml);
    
    # Restore the original non-ASCII characters
    $xml =~ s/__([a-z_0-9]+)__/$char_map{"__$1__"}/ge;
    
    return $xml;
}