package LANraragi::Plugin::Metadata::ETagCN;

use strict;
use warnings;
no warnings 'uninitialized';
use utf8;
#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(html_unescape);
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);


#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name       => "E-Hentai_CN",
        type       => "metadata",
        namespace  => "etagcn",
        login_from => "ehlogin",
        author     => "GrayZhao & Difegue and others",
        version    => "2.5.1",
        description =>
          "搜索 g.e-hentai 以查找与您的存档匹配的标签,并将原标签翻译为中文标签. <br/><i class='fa fa-exclamation-circle'></i> 此插件将使用存档的 source: tag （如果存在）",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAEnQAABJ0Ad5mH3gAAAOASURBVDhPjVNbaFRXFF3n3puZyZ3EzJ1HkpIohthAP0InYMAKUUpfVFDylY9Bg1CJ+UllfLSEIoIEtBan7Y9t8KO0pSU0lH74oQZsMWImkSBalUADqR8mTVOTyXMymcfd7nPuNZpo2yzm3DmPfdZZZ+91MDyYJA0g+AMkStY3i8Brn392jjYKIclK7hP0rNzK7XkIIM8BdlRgkdYvvhya7bcUGT0ugKbXNZ4zcsCS+Qoycyl3y39DCL5qoJ+DpUKvM6mwzIcsFQCfjtmfL+LQX5cRa+9AOp12A57Btm1UV1ejoaHBIbTupDB/YB/yg5fcEKDo3VaUnPoWlLZBfg1zOwU6OjqQSr2o1DAMJJNJNDU1OYTBeynMNFbBPHoRwirnxOWgVW2DVhbh4wsQQR2p3VWgxXGX4uWQxJxyFyvLKHpzDzy7tsOz+w1olkMmQfKW+z/Gmc7javxvKC0t5SSywtCfRFplDYlNIRJlES65QYEbRNYQrf77bxFtKRauOYj6+vook8m4IweBAFtNXfl+CtP1FszD56VuLo6J/O/XYT98AL1+FwojQxChSuRuXsV3X55mywbR1taGlpYWlbfx8XHEYjFVFEfhQ2UyCriKAv2sapjIF/+agndZ3dmrZP1GpH/4Fb1eu0XF9vT0UHd3t+onEgkaGxuj8vJy+UieQfPzASxQNqxwyyyD2D5YmoU9PwfP3naETS+i0Siam5vBJOjq6kI8HkdNTQ2y2SzkVmZQXyydPMIEC+y/eRQfuQAU8mreznBVhIAvBFwb+YeLdA+6z0RFRQUmJiZUzFMohVKFr/UUq5jmAU/ofM5KGkWN74HY8MarnBtv8Wq1T350DLquw+PxyO1rIOC3KJicQbZ/SFpeKUGBvVfGchhaZDOEybnIs4U0HTYfOP+OABcVvb29qjCyL2FZlrysTqHJPBY+OMwbpGBJmIPx2g5FbuzYC30ze9KxJEQYmIlWclom1Xh0dBR1dXWKNBwOQxxtP0SJn/qBne+vGlmBXwtHATmujtfDP9nn3Hj9WBn4FefiB3Gi8xM32IFSKA05cvc2Jh894rysKbqCaZq48MWn+OaPrUBjTKUD37+Fqam/EYnwM30OklBK/V8spqYIRh3hB8evd4YH3ZW1YELaEKGE32sQKt6mK7/86M68CHnYhgkTifNqQ21trVKyvsm1gYEBegL+M2W04901FQAAAABJRU5ErkJggg==",
        parameters => [
            { type => "string", desc => "在搜索中强制使用语言（由于 EH 限制，日语无法使用）" },
            { type => "bool",   desc => "保存档案名称" },
            { type => "bool",   desc => "首先使用缩略图获取（否则使用标题）" },
            { type => "bool",   desc => "使用 ExHentai（可以在没有星形 cookie 的情况下搜索fjorded内容）" },
            {   type => "bool",
                desc => "如果可用，请保存原始标题，而不是英文或罗马拼音标题"
            },
            { type => "bool", desc => "获取额外的时间戳（发布时间）和上传者元数据" },
            { type => "bool", desc => "搜索已删除的图库" },
            { type => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" },
        ],
        oneshot_arg => "该漫画在e-hentai的URL(将于确切的漫画相匹配的标签到你的档案中)",
        cooldown    => 4
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                     # Global info hash
    my $ua       = $lrr_info->{user_agent};
    my ( $lang, $savetitle, $usethumbs, $enablepanda, $jpntitle, $additionaltags, $expunged, $db_path ) = @_;    # Plugin parameters

    # Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_plugin_logger();

    # Work your magic here - You can create subroutines below to organize the code better
    my $gID    = "";
    my $gToken = "";
    my $domain = ( $enablepanda ? 'https://exhentai.org' : 'https://e-hentai.org' );
    my $hasSrc = 0;

    # Quick regex to get the E-H archive ids from the provided url or source tag
    if ( $lrr_info->{oneshot_param} =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
        $logger->debug("Skipping search and using gallery $gID / $gToken from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*e(?:x|-)hentai\.org\/g\/([0-9]*)\/([0-z]*)\/*.*/gi ) {
        $gID    = $1;
        $gToken = $2;
        $hasSrc = 1;
        $logger->debug("Skipping search and using gallery $gID / $gToken from source tag");
    } else {

        # Craft URL for Text Search on EH if there's no user argument
        ( $gID, $gToken ) = &lookup_gallery(
            $lrr_info->{archive_title},
            $lrr_info->{existing_tags},
            $lrr_info->{thumbnail_hash},
            $ua, $domain, $lang, $usethumbs, $expunged
        );
    }

    # If an error occured, return a hash containing an error message.
    # LRR will display that error to the client.
    # Using the GToken to store error codes - not the cleanest but it's convenient
    if ( $gID eq "" ) {

        if ( $gToken ne "" ) {
            $logger->error($gToken);
            return ( error => $gToken );
        }

        $logger->info("No matching EH Gallery Found!");
        return ( error => "No matching EH Gallery Found!" );
    } else {
        $logger->debug("EH API Tokens are $gID / $gToken");
    }

    my ( $ehtags, $ehtitle ) = &get_tags_from_EH( $ua, $gID, $gToken, $jpntitle, $additionaltags,$db_path );
    my %hashdata = ( tags => $ehtags );

    # Add source URL and title if possible/applicable
    if ( $hashdata{tags} ne "" ) {

        if ( !$hasSrc ) { $hashdata{tags} .= ", source:" . ( split( '://', $domain ) )[1] . "/g/$gID/$gToken"; }
        if ($savetitle) { $hashdata{title} = $ehtitle; }
    }

    #Return a hash containing the new metadata - it will be integrated in LRR.
    return %hashdata;
}

######
## EH Specific Methods
######

sub lookup_gallery {

    my ( $title, $tags, $thumbhash, $ua, $domain, $defaultlanguage, $usethumbs, $expunged ) = @_;
    my $logger = get_plugin_logger();
    my $URL    = "";

    #Thumbnail reverse image search
    if ( $thumbhash ne "" && $usethumbs ) {

        $logger->info("Reverse Image Search Enabled, trying now.");

        #search with image SHA hash
        $URL =
            $domain
          . "?advsearch=1&f_sname=on&f_sdt2=on&f_spf=&f_spt=&f_sfu=on&f_sft=on&f_sfl=on&f_shash="
          . $thumbhash
          . "&fs_covers=1&fs_similar=1";

        #Include expunged galleries in the search if the option is enabled.
        if ($expunged) {
            $URL = $URL . "&fs_exp=1";
        }

        # Add the language override, if it's defined.
        if ( $defaultlanguage ne "" ) {

            # Add f_stags to search in tags for language
            $URL = $URL . "&f_stags=on&f_search=" . uri_escape_utf8("language:$defaultlanguage");
        }

        $logger->debug("Using URL $URL (archive thumbnail hash)");

        my ( $gId, $gToken ) = &ehentai_parse( $URL, $ua );

        if ( $gId ne "" && $gToken ne "" ) {
            return ( $gId, $gToken );
        }
    }

    # Regular text search
    $URL =
        $domain
      . "?advsearch=1&f_sname=on&f_sdt2=on&f_spf=&f_spt=&f_sfu=on&f_sft=on&f_sfl=on"
      . "&f_search="
      . uri_escape_utf8( qw(") . $title . qw(") );

    my $has_artist = 0;

    # Add artist tag from the OG tags if it exists
    if ( $tags =~ /.*artist:\s?([^,]*),*.*/gi ) {
        $URL        = $URL . "+" . uri_escape_utf8("artist:$1");
        $has_artist = 1;
    }

    # Add the language override, if it's defined.
    if ( $defaultlanguage ne "" ) {
        $URL = $URL . "+" . uri_escape_utf8("language:$defaultlanguage");
    }

    # Add f_stags to search in tags if we added a tag (or two) in the search
    if ( $has_artist || $defaultlanguage ne "" ) {
        $URL = $URL . "&f_stags=on";
    }

    # Include expunged galleries in the search if the option is enabled.
    if ($expunged) {
        $URL = $URL . "&f_sh=on";
    }

    $logger->debug("Using URL $URL (archive title)");
    return &ehentai_parse( $URL, $ua );
}

# ehentai_parse(URL, UA)
# Performs a remote search on e- or exhentai, and returns the ID/token matching the found gallery.
sub ehentai_parse() {

    my ( $url, $ua ) = @_;

    my $logger = get_plugin_logger();

    my ( $dom, $error ) = search_gallery( $url, $ua );
    if ($error) {
        return ( "", $error );
    }

    my $gID    = "";
    my $gToken = "";

    eval {
        # Get the first row of the search results
        # The "glink" class is parented by a <a> tag containing the gallery link in href.
        # This works in Minimal, Minimal+ and Compact modes, which should be enough.
        my $firstgal = $dom->at(".glink")->parent->attr('href');

        # A EH link looks like xhentai.org/g/{gallery id}/{gallery token}
        my $url    = ( split( 'hentai.org/g/', $firstgal ) )[1];
        my @values = ( split( '/',             $url ) );

        $gID    = $values[0];
        $gToken = $values[1];
    };

    if ( index( $dom->to_string, "You are opening" ) != -1 ) {
        my $rand = 15 + int( rand( 51 - 15 ) );
        $logger->info("Sleeping for $rand seconds due to EH excessive requests warning");
        sleep($rand);
    }

    #Returning shit yo
    return ( $gID, $gToken );
}

sub search_gallery {

    my ( $url, $ua ) = @_;
    my $logger = get_plugin_logger();

    my $res = $ua->max_redirects(5)->get($url)->result;

    if ( index( $res->body, "Your IP address has been" ) != -1 ) {
        return ( "", "Temporarily banned from EH for excessive pageloads." );
    }

    return ( $res->dom, undef );
}

# get_tags_from_EH(userAgent, gID, gToken, jpntitle, additionaltags, $db_path)
# Executes an e-hentai API request with the given JSON and returns tags and title.
sub get_tags_from_EH {

    my ( $ua, $gID, $gToken, $jpntitle, $additionaltags, $db_path ) = @_;
    my $uri = 'https://api.e-hentai.org/api.php';

    my $logger = get_plugin_logger();

    my $jsonresponse = get_json_from_EH( $ua, $gID, $gToken );

    #if an error occurs(no response) return empty strings.
    if ( !$jsonresponse ) {
        return ( "", "" );
    }

    my $data    = $jsonresponse->{"gmetadata"};
    my @tags    = @{ @$data[0]->{"tags"} };
    my $ehtitle = @$data[0]->{ ( $jpntitle ? "title_jpn" : "title" ) };
    if ( $ehtitle eq "" && $jpntitle ) {
        $ehtitle = @$data[0]->{"title"};
    }
    my $ehcat = lc @$data[0]->{"category"};

    push( @tags, "reclass:$ehcat" );
    if ($additionaltags) {
        my $ehuploader  = @$data[0]->{"uploader"};
        my $ehtimestamp = @$data[0]->{"posted"};
        push( @tags, "上传者:$ehuploader" );
        push( @tags, "时间戳:$ehtimestamp" );
    }

    # Unescape title received from the API as it might contain some HTML characters
    $ehtitle = html_unescape($ehtitle);

    # 中文转换
    my $cntags = translate_tag_to_cn( \@tags, $db_path );

    my $ehtags = join( ', ', @$cntags );
    $logger->info("Sending the following tags to LRR: $ehtags");

    return ( $ehtags, $ehtitle );
}

sub get_json_from_EH {

    my ( $ua, $gID, $gToken ) = @_;
    my $uri = 'https://api.e-hentai.org/api.php';

    my $logger = get_plugin_logger();

    #Execute the request
    my $rep = $ua->post(
        $uri => json => {
            method    => "gdata",
            gidlist   => [ [ $gID, $gToken ] ],
            namespace => 1
        }
    )->result;

    my $textrep = $rep->body;
    $logger->debug("E-H API returned this JSON: $textrep");

    my $jsonresponse = $rep->json;
    if ( exists $jsonresponse->{"error"} ) {
        return;
    }

    return $jsonresponse;
}

# 将原tag翻译为中文tag
sub translate_tag_to_cn {
    my $logger = get_plugin_logger();
    my ($list, $db_path) = @_;
    my $filename = $db_path; # json 文件的路径
    my $json_text = do {
        open(my $json_fh, "<", $filename)
            or $logger->debug("Can't open $filename: $!\n");
        local $/;
        <$json_fh>;
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

1;