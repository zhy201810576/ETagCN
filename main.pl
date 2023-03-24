use strict;
use warnings;
use JSON;

sub process_json_data {
    my ($list, $file_path) = @_;
    my $filename = $file_path; # json 文件的路径
    my $json_text = do {
        open(my $json_fh, "<", $filename)
            or die("Can't open $filename: $!\n");
        local $/;
        <$json_fh>
    };
    my $json = decode_json($json_text);
    my $target = $json->{'data'};

    for my $item (@$list) {
        my ($namespace, $key) = split(/:/, $item);
        for my $element (@$target) {
            # 如果$namespace与'namespace'字段相同，则进行替换
            if ($element->{'namespace'} eq $namespace) {
                my $name = $element->{'frontMatters'}->{'name'};
                $item =~ s/$namespace/$name/;
                my $data = $element->{'data'};
                # 如果在'data'字段中存在$key，则进行替换
                if (exists $data->{$key}) {
                    my $value = $data->{$key}->{'name'};
                    $item =~ s/$key/$value/;
                }
                last;
            }
        }
    }
    
    return $list;
}


my @list = ("artist:gentsuki", "female:ponytail","female:schoolgirl uniform", "other:no penetration");
my $file_path = "ETagCN/db.text.json";
my $result = process_json_data(\@list, $file_path);
print join(",", @$result), "\n";
# 输出 "艺术家:2"
