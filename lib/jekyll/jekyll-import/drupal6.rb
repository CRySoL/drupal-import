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
             WHERE (n.type = 'blog' OR n.type = 'story') \
             AND n.vid = nr.vid"


    def self.get_user_for_node(db, uid)
      author = db[:users].where(:uid=>uid).first[:name]
      author.gsub(".", "_")
    end

    def self.get_category_for_node(db, nid)
      category = db.fetch("select d.name from term_node as n, term_data as d where n.nid = %s and n.tid = d.tid and d.vid = 1" % nid).first
      if category
        return category[:name].sub(':: ', '')
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

    def self.process(dbname, user, pass, host = 'localhost', prefix = '')
      db = Sequel.mysql(dbname, :user => user, :password => pass, :host => host, :encoding => 'utf8')

      if prefix != ''
        QUERY[" node "] = " " + prefix + "node "
        QUERY[" node_revisions "] = " " + prefix + "node_revisions "
      end

      FileUtils.mkdir_p "_posts"
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
      skip = [260, 261, 207, 1368, 33, 35, 59,
              99, 339,  # syntax error
              182, 302,
              ]

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
        dir = is_published ? "_posts" : "_drafts"
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

        content.gsub!('[code]',                   "\n<temp-div>\n{% highlight text %}")


        content.gsub!(/\[code\s*\w+=shell\s*[\w=]*\]/,   "\n<temp-div class=\"console\">\n{% highlight console %}\n")
        content.gsub!(/\[code\s*\w+=console\s*[\w=]*\]/, "\n<temp-div class=\"console\">\n{% highlight console %}\n")

#        content.gsub!("[code class=shell]",       "\n<temp-div class=\"console\">\n{% highlight console %}\n")
#        content.gsub!("[code type=shell]",        "\n<temp-div class=\"console\">\n{% highlight console %}\n")
#        content.gsub!("[code class=console]",     "\n<temp-div class=\"console\">\n{% highlight console %}\n")
#        content.gsub!("[code type=console]",      "\n<temp-div class=\"console\">\n{% highlight console %}\n")
#        content.gsub!("[code lang=console]",      "\n<temp-div class=\"console\">\n{% highlight console %}\n")
#        content.gsub!("[code language=console]",  "\n<temp-div class=\"console\">\n{% highlight console %}\n")

        content.gsub!(/\[code\s*\w+=lisp\s*[\w=]*\]/,            "\n<temp-div>\n{% highlight text %}")
        content.gsub!(/\[code\s*\w+="?XML"?\s*[\w=]*\]/,         "\n<temp-div>\n{% highlight xml %}")
        content.gsub!(/\[code\s*\w+="?html4strict"?\s*[\w=]*\]/, "\n<temp-div>\n{% highlight html %}")
        content.gsub!(/\[code\s*\w+=Makefile\s*[\w=]*\]/,        "\n<temp-div>\n{% highlight make %}")
        content.gsub!(/\[code\s*\w+=PHP\s*[\w=]*\]/,             "\n<temp-div>\n{% highlight php %}")
        content.gsub!(/\[code\s*\w+="?(\w+)"?(\s+[\w=\d]*)*\]/,  "\n<temp-div>\n{% highlight \\1 %}")

#         content.gsub!("[code class=bash]",        "\n<temp-div>\n{% highlight bash %}")
#         content.gsub!("[code type=bash]",         "\n<temp-div>\n{% highlight bash %}")
#         content.gsub!("[code type=python]",       "\n<temp-div>\n{% highlight python %}")
#         content.gsub!("[code lang=python]",       "\n<temp-div>\n{% highlight python %}")
#         content.gsub!("[code language=python]",   "\n<temp-div>\n{% highlight python %}")
#         content.gsub!("[code lang=php]",          "\n<temp-div>\n{% highlight php %}")
#         content.gsub!("[code type=PHP]",          "\n<temp-div>\n{% highlight php %}")
#         content.gsub!("[code class=c]",           "\n<temp-div>\n{% highlight c %}")
#         content.gsub!("[code type=c]",            "\n<temp-div>\n{% highlight c %}")
#         content.gsub!("[code class=cpp]",         "\n<temp-div>\n{% highlight cpp %}")
#         content.gsub!("[code type=cpp]",          "\n<temp-div>\n{% highlight cpp %}")
#         content.gsub!("[code class=html4strict]", "\n<temp-div>\n{% highlight html %}")
#         content.gsub!("[code type=mysql]",        "\n<temp-div>\n{% highlight sql %}")
#         content.gsub!("[code language=ini]",      "\n<temp-div>\n{% highlight ini %}")
#         content.gsub!("[code type=Makefile]",     "\n<temp-div>\n{% highlight make %}")
#         content.gsub!("[code type=make]",         "\n<temp-div>\n{% highlight make %}")
#         content.gsub!("[code lang=Makefile]",     "\n<temp-div>\n{% highlight make %}")
#         content.gsub!("[code lang=make]",         "\n<temp-div>\n{% highlight make %}")
        content.gsub!('[/code]',                  "{% endhighlight %}\n</temp-div>")


        content.gsub!('<kbd>',                    "\n<temp-div class=\"console\">\n{% highlight console %}\n")
        content.gsub!('</kbd>',                   "{% endhighlight %}\n</temp-div>")
        content.gsub!('</kdb>',                   "{% endhighlight %}\n</temp-div>")

        content.gsub!('<notextile>', '')
        content.gsub!('</notextile>', '')


        content.gsub!(':http', '::ttp')
#        content = Rinku.auto_link(content, mode=:urls, skip_tags="temp-div")
        content.gsub!('::ttp', ':http')

        content.gsub!('temp-div', 'div')

        parts = content.split('<!--break-->')
        if parts[1] and parts[1].length < 10
          content.gsub!('<!--break-->', '')
        end

        # Write out the data and content to file
        File.open("#{dir}/#{name}", "w") do |f|
          f.puts data
          f.puts "---"
          f.puts content
        end

        # Make a file to redirect from the old Drupal URL
        if is_published
          aliases = db["SELECT dst FROM #{prefix}url_alias WHERE src = ?", "node/#{node_id}"].all

          aliases.push(:dst => "node/#{node_id}")

          aliases.each do |url_alias|
            FileUtils.mkdir_p url_alias[:dst]
            File.open("#{url_alias[:dst]}/index.md", "w") do |f|
              f.puts "---"
              f.puts "layout: refresh"
              f.puts "refresh_to_post_id: /#{category}/#{time.strftime("%Y-%m-%d/") + slug}"
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
