# -*- coding: utf-8 -*-
require 'rubygems'
require 'sequel'
require 'fileutils'
require 'safe_yaml'

require 'rinku'


# NOTE: This converter requires Sequel and the MySQL gems.
# The MySQL gem can be difficult to install on OS X. Once you have MySQL
# installed, running the following commands should work:
# $ sudo gem install sequel
# $ sudo gem install mysql -- --with-mysql-config=/usr/local/mysql/bin/mysql_config

module JekyllImport
  module Drupal6
    # Reads a MySQL database via Sequel and creates a post file for each story
    # and blog node in table node.
    QUERY = "SELECT n.nid, \
                    n.uid,
                    n.title, \
                    nr.body, \
                    n.created, \
                    n.status \
             FROM node AS n, \
                  node_revisions AS nr \
             WHERE (n.type = 'blog' OR n.type = 'story' ) \
             AND n.vid = nr.vid"

# n.type = 'frase'


    def self.get_user_for_node(db, uid)
      author = db[:users].where(:uid=>uid).first[:name]
      author.gsub(".", "_")
    end

    def self.get_category_for_node(db, nid)
      category = db.fetch("select d.name from term_node as n, term_data as d where n.nid = %s and n.tid = d.tid and d.vid = 1" % nid).first
      if category
        retval = category[:name]
        return retval
      else
        return nil
      end
    end

    def self.get_tags_for_node(db, nid)
      tags = []
      ds = db.fetch("select d.name from term_node as n, term_data as d where n.nid = %s and n.tid = d.tid and d.vid != 1" % nid)
      ds.each do |tag|
        tags.push(tag[:name])
      end
      return tags
    end

    def self.get_node_format(db, nid)
      reg = db.fetch("select f.name from node as n, node_revisions as r, filter_formats as f where n.nid=%s and r.vid = n.vid and r.format=f.format;" % nid).first
      return reg[:name].downcase
    end

    def self.get_users(db)
      ds = db[:users]
      ds.each do |user|
        nodes = db[:node].where("uid=%s" % user[:uid])
        if not nodes.first
          next
        end
        picture = user[:picture]
        puts "%s:" % user[:name].sub('.', '_')
        puts "  name: " + user[:name]
        puts "  email: " + user[:mail]
        if picture.length > 1
            puts "  picture: " + picture
        end
      end
    end

    def self.process(dbname, user, pass, host = 'localhost', prefix = '')
      db = Sequel.mysql(dbname, :user => user, :password => pass, :host => host, :encoding => 'utf8')

      if prefix != ''
        QUERY[" node "] = " " + prefix + "node "
        QUERY[" node_revisions "] = " " + prefix + "node_revisions "
      end

      FileUtils.mkdir_p "_posts/migrated"
      FileUtils.mkdir_p "_drafts"

      # Create the refresh layout
      # Change the refresh url if you customized your permalink config
      File.open("_layouts/refresh.html", "w") do |f|
        f.puts <<EOF
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<meta http-equiv="refresh" content="0;url={{ page.refresh_to_post_id }}" />
</head>
</html>
EOF
      end


      only = [4, 6, 1695, 1704, 1705]
      only = [1440, 1701]
      only = [1358]
      only = []
      skip = [
              # do not exist
              260, 261,
              931, # listado s código en crysol
              # wrong
              207, # offus C {% raw %}
              # fixed
#              1277, 1342, 1438, 516, 509, 697, 59, 182, 99, 339, 649, 1221, 302,
              # OK
#1705, 1704, 1695, 1703, 1702, 1701, 1699, 1698, 1697, 1696, 1694, 1691, 1690, 1688, 1687, 1686, 1578, 1574, 1573, 1570, 1569, 1568, 1567, 1566, 1565, 1564, 1563, 1562, 1561, 1559, 1558, 1557, 1556, 1555, 1553, 1551, 1550, 1549, 1548, 1546, 1544, 1542, 1541, 1538, 1537, 1535, 1534, 1532, 1529, 1530, 1531, 1527, 1526, 1524, 1525, 1523, 1522, 1520, 1519, 1518, 1517, 1516, 1515, 1514, 1513, 1512, 1511, 1510, 1508, 1506, 1505, 1501, 1498, 1500, 1497, 1496, 1495, 1494, 1493, 1491, 1490, 1489, 1488, 1487, 1486, 1485, 1481, 1484, 1478, 1477, 1476, 1475, 1474, 1473, 1460, 1459, 1457, 1456, 1454, 1453, 1452, 1451, 1449, 1448, 1447, 1446, 1444, 1443, 1442, 1441, 1440, 1439, 1437, 1435, 1434, 1433, 1431, 1432, 1430, 1429, 1427, 1428, 1426, 1425, 1424, 1423, 1421, 1420, 1419, 1422, 1418, 1417, 1416, 1414, 1413, 1412, 1410, 1409, 1407, 1406, 1405, 1403, 1401, 1399, 1398, 1397, 1396, 1395, 1394, 1393, 1392, 1390, 1389, 1388, 1386, 1384, 1380, 1377, 1376, 1374, 1373, 1528, 1371, 1370, 1369, 1367, 1365, 1364, 1363, 1362, 1361, 1360, 1359, 1358, 1357, 1356, 1355, 1354, 1353, 1352, 1351, 1350, 1349, 1348, 1345, 1346, 1347, 1344, 1343, 1341, 1340, 1339, 1338, 1336, 1335, 1333, 1332, 1330, 1331, 1329, 1328, 1327, 1326, 1325, 1324, 1323, 1322, 1321, 1320, 1319, 1317, 1316, 1278, 1276, 1275, 1274, 1273, 1272, 1271, 1270, 1269, 1268, 1265, 1266, 1264, 1262, 1260, 1259, 1257, 1258, 1256, 1254, 1253, 1245, 1246, 1242, 1241, 1240, 1239, 1238, 1237, 1236, 1235, 1233, 1234, 1230, 1231, 1228, 1226, 1227, 1225, 1224, 1223, 1222, 1220, 1219, 1218, 1217, 1215, 1216, 1213, 1212, 1138, 1137, 1136, 1135, 1131, 1130, 1129, 1127, 1126, 1125, 1124, 1123, 1122, 1121, 1120, 1119, 1118, 1117, 1116, 1115, 1114, 1113, 1112, 1111, 1110, 1109, 1107, 1108, 1106, 1105, 1103, 1102, 1100, 1101, 1096, 1095, 1094, 1093, 1091, 1092, 1090, 1089, 1087, 1088, 1086, 1085, 1084, 1083, 1082, 1081, 1080, 1079, 934, 1075, 1077, 1076, 1074, 1072, 1071, 1004, 1070, 1069, 1068, 1066, 1065, 1064, 1063, 1059, 1058, 1057, 1056, 1055, 1053, 1051, 1050, 1049, 1048, 1046, 1045, 1044, 1043, 1041, 1040, 1039, 1038, 1037, 1036, 1035, 1030, 1034, 1031, 1033, 1029, 1028, 1027, 1026, 1024, 1025, 1023, 1022, 1021, 1020, 1019, 1016, 1015, 1014, 1013, 1012, 1010, 1009, 1006, 1007, 1005, 1002, 1000, 1001, 995, 999, 998, 997, 996, 993, 992, 991, 988, 989, 990, 986, 985, 984, 971, 970, 967, 968, 966, 965, 963, 964, 962, 960, 959, 957, 958, 954, 950, 949, 951, 945, 944, 906, 943, 942, 939, 937, 938, 936, 935, 933, 932, 926, 924, 1073, 923, 922, 921, 920, 919, 918, 915, 914, 913, 912, 911, 908, 909, 907, 905, 904, 901, 840, 898, 899, 897, 896, 895, 894, 893, 892, 891, 890, 889, 888, 887, 886, 885, 883, 882, 881, 880, 879, 878, 877, 876, 875, 874, 873, 872, 869, 868, 870, 866, 867, 865, 864, 863, 861, 860, 859, 858, 857, 856, 855, 853, 852, 851, 850, 848, 846, 845, 844, 842, 1572, 843, 841, 839, 837, 838, 836, 835, 833, 831, 829, 827, 825, 822, 823, 821, 815, 819, 818, 817, 816, 812, 814, 813, 807, 811, 810, 809, 808, 806, 804, 803, 675, 801, 800, 798, 797, 796, 795, 794, 792, 790, 789, 788, 782, 781, 780, 779, 778, 776, 777, 775, 774, 773, 772, 771, 770, 769, 768, 767, 765, 766, 764, 761, 760, 759, 758, 757, 753, 751, 752, 750, 749, 747, 746, 745, 744, 743, 742, 740, 738, 739, 737, 791, 735, 734, 733, 731, 730, 1017, 1018, 600, 729, 728, 726, 727, 725, 720, 719, 717, 783, 714, 715, 713, 712, 710, 709, 708, 705, 703, 704, 701, 702, 700, 692, 699, 698, 696, 695, 694, 693, 691, 685, 689, 690, 688, 686, 687, 681, 682, 683, 679, 673, 676, 674, 677, 672, 671, 669, 667, 666, 665, 656, 655, 654, 653, 652, 651, 661, 648, 647, 646, 645, 642, 643, 641, 640, 639, 637, 636, 635, 634, 632, 633, 631, 630, 629, 628, 627, 625, 626, 624, 623, 622, 621, 618, 620, 619, 615, 616, 325, 613, 611, 612, 609, 610, 608, 607, 606, 605, 604, 603, 579, 602, 599, 598, 597, 596, 594, 595, 593, 592, 591, 590, 585, 589, 586, 582, 583, 584, 581, 578, 574, 575, 722, 522, 572, 571, 513, 514, 521, 570, 568, 566, 562, 558, 560, 561, 559, 556, 553, 552, 550, 549, 548, 554, 546, 544, 542, 543, 541, 540, 539, 538, 536, 537, 535, 534, 532, 533, 530, 531, 529, 528, 511, 517, 491, 518, 515, 506, 505, 503, 501, 500, 497, 498, 494, 496, 495, 492, 493, 490, 489, 483, 484, 482, 481, 479, 478, 477, 476, 475, 472, 473, 471, 470, 468, 469, 467, 466, 465, 462, 460, 459, 458, 457, 456, 455, 454, 453, 451, 452, 448, 450, 447, 446, 445, 443, 441, 442, 438, 437, 435, 434, 433, 432, 431, 430, 429, 428, 421, 420, 418, 416, 414, 413, 412, 409, 408, 411, 410, 406, 407, 405, 404, 403, 402, 401, 399, 400, 398, 397, 396, 395, 394, 393, 391, 390, 389, 388, 387, 386, 385, 384, 382, 381, 377, 380, 378, 375, 373, 372, 370, 371, 369, 368, 367, 363, 365, 366, 364, 361, 362, 360, 358, 356, 357, 353, 354, 352, 350, 349, 347, 343, 342, 341, 338, 337, 336, 335, 334, 333, 332, 331, 330, 329, 328, 326, 327, 323, 322, 321, 319, 315, 314, 312, 313, 308, 311, 310, 307, 306, 305, 304, 298, 299, 297, 296, 295, 294, 293, 292, 291, 290, 288, 287, 289, 286, 285, 284, 283, 282, 281, 280, 279, 1383, 278, 277, 276, 273, 275, 272, 271, 270, 269, 267, 266, 265, 264, 263, 259, 262, 258, 256, 257, 254, 255, 253, 252, 249, 250, 248, 247, 246, 245, 244, 243, 242, 239, 241, 237, 236, 234, 233, 235, 231, 184, 229, 230, 228, 227, 226, 224, 223, 222, 221, 1097, 219, 220, 218, 217, 216, 214, 802, 215, 212, 211, 213, 208, 204, 203, 209, 202, 201, 200, 198, 199, 196, 197, 195, 194, 193, 192, 191, 189, 188, 187, 183, 185, 178, 181, 180, 177, 176, 169, 175, 174, 173, 172, 171, 168, 170, 166, 162, 83, 164, 163, 161, 160, 158, 157, 156, 154, 155, 153, 152, 150, 147, 149, 148, 135, 145, 143, 142, 144, 141, 140, 139, 138, 137, 136, 132, 134, 131, 130, 129, 128, 127, 123, 124, 118, 126, 121, 117, 122, 119, 120, 112, 114, 116, 115, 113, 111, 109, 106, 108, 103, 102, 100, 98, 662, 96, 94, 95, 92, 93, 87, 86, 84, 85, 82, 81, 80, 79, 78, 75, 74, 73, 70, 65, 67, 64, 57, 58, 50, 49, 52, 53, 51, 46, 47, 43, 42, 40, 38, 34, 29, 32, 28, 26, 25, 19, 4, 17, 15, 14, 13, 12, 11, 6,
              ]

      self.get_users(db)

      db[QUERY].each do |post|
        # Get required fields and construct Jekyll compatible name
        node_id = post[:nid]
        user_id = post[:uid]

        if skip.include?(node_id)
          next
        end

        if only.length > 0  and not only.include?(node_id)
          next
        end

        puts '---'
        puts node_id

        title = post[:title]
        content = post[:body]
        created = post[:created]
        time = Time.at(created)
        is_published = post[:status] == 1
        dir = is_published ? "_posts/migrated" : "_drafts"
        slug = title.strip.downcase.gsub(/(&|&amp;)/, ' and ').gsub(/[\s\.\/\\]/, '-').gsub(/[^\w-]/, '').gsub(/[-_]{2,}/, '-').gsub(/^[-_]/, '').gsub(/[-_]$/, '')

        category = self.get_category_for_node(db, node_id)
        tags = self.get_tags_for_node(db, node_id)

        format = self.get_node_format(db, node_id)
        if format.include? 'textile'
          format = 'textile'
        else
          format = 'html'
        end

        name = time.strftime("%Y-%m-%d-") + slug + '.' + format
        puts name
        puts title
        puts format
        puts category
        puts tags

        # Get the relevant fields as a hash, delete empty fields and convert
        # to YAML for the header
        front_matter = {
           'migrated' => 'node/%s' % node_id,
           'layout' => 'post',
           'title' => title.to_s,
           'created' => created,
           'author' => self.get_user_for_node(db, user_id)
         }

        if category
          front_matter['category'] = category
        end

        if tags.length > 0
            front_matter['tags'] = tags
        end

        data = front_matter.delete_if { |k,v| v.nil? || v == ''}.to_yaml

        content.gsub!(/\r\n/, "\n")

        content.gsub!('[code]',                   "\n<pre div>\n{% highlight text %}")


        content.gsub!(/\[code\s*\w+=["']?shell["']?\s*[\w=]*\]/,       "\n<pre div class=\"console\">\n{% highlight console %}\n")
        content.gsub!(/\[code\s*\w+=["']?console["']?\s*[\w=]*\]/,     "\n<pre div class=\"console\">\n{% highlight console %}\n")

        content.gsub!(/\[code\s*\w+=["']?html4strict["']?\s*[\w=]*\]/, "\n<pre div>\n{% highlight html %}")
        content.gsub!(/\[code\s*\w+=["']?lisp["']?\s*[\w=]*\]/,        "\n<pre div>\n{% highlight text %}")
        content.gsub!(/\[code\s*\w+=["']?none["']?\s*[\w=]*\]/,        "\n<pre div>\n{% highlight text %}")
        content.gsub!(/\[code\s*\w+=["']?XML["']?\s*[\w=]*\]/,         "\n<pre div>\n{% highlight xml %}")
        content.gsub!(/\[code\s*\w+=["']?INI["']?\s*[\w=]*\]/,         "\n<pre div>\n{% highlight ini %}")
        content.gsub!(/\[code\s*\w+=Makefile\s*[\w=]*\]/,              "\n<pre div>\n{% highlight make %}")
        content.gsub!(/\[code\s*\w+=PHP\s*[\w=]*\]/,                   "\n<pre div>\n{% highlight php %}")
        content.gsub!(/\[code\s*\w+=["']?(\w+)["']?(\s+[\w=\d]*)*\]/,  "\n<pre div>\n{% highlight \\1 %}")


        content.gsub!('[/code]',                  "{% endhighlight %}\n</pre div>")


        content.gsub!('<kbd>',                    "\n<pre div class=\"console\">\n{% highlight console %}\n")
        content.gsub!('</kbd>',                   "\n{% endhighlight %}\n</pre div>")
        content.gsub!('</kdb>',                   "\n{% endhighlight %}\n</pre div>")

        content.gsub!('<notextile>', '')
        content.gsub!('</notextile>', '')

        content.gsub!('bq. ', '')

        # links
        content.gsub!(':http', '::ttp')
        content.gsub!(':http://www', '::ttp::ww')
        content = Rinku.auto_link(content, mode=:urls)
        content.gsub!('::ttp', ':http')
        content.gsub!( '::ttp::ww', ':http://www')
        content.gsub!("http://crysol.org/files/", "/assets/files/")

        content.gsub!('pre div', 'div')

        content.gsub!("</blockquote>", "</blockquote><!--break-->")

        if content.length > 400
          puts "content size %s" % content.length
          a, b = content.split("\n", 2)
          if a and b and not content.include? "<!--break-->"
            content = a + "<!--break-->" + b
          end
        end

        parts = content.split('<!--break-->')
        if parts[1] and parts[1].length < 10
          content.gsub!('<!--break-->', '')
        end

        content.gsub!("<!--break-->", "\n\n<!--break-->\n\n")

        # Write out the data and content to file
        File.open("#{dir}/#{name}", "w") do |f|
          f.puts data
          f.puts "---"
          f.puts content
        end

        # Make a file to redirect from the old Drupal URL
        if is_published
          target = "/#{time.strftime("%Y-%m-%d/") + slug}"
          if category
              target = "/#{category}" + target
          end

          aliases = db["SELECT dst FROM #{prefix}url_alias WHERE src = ?", "node/#{node_id}"].all

          aliases.push(:dst => "node/#{node_id}")

          aliases.each do |url_alias|
            FileUtils.mkdir_p "p/%s" % url_alias[:dst]
            File.open("p/#{url_alias[:dst]}/index.md", "w") do |f|
              f.puts "---"
              f.puts "layout: refresh"
              f.puts "refresh_to_post_id: %s" % target
              f.puts "---"
            end
          end
        end
      end

      # TODO: Make dirs & files for nodes of type 'page'
        # Make refresh pages for these as well

      # TODO: Make refresh dirs & files according to entries in url_alias table
    end
  end
end
