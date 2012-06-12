	;
	; This file is part of DataBallet.
	; Copyright (C) 2012 Laurent Parenteau <laurent.parenteau@gmail.com>
	;
	; DataBallet is free software: you can redistribute it and/or modify
	; it under the terms of the GNU Affero General Public License as published by
	; the Free Software Foundation, either version 3 of the License, or
	; (at your option) any later version.
	;
	; DataBallet is distributed in the hope that it will be useful,
	; but WITHOUT ANY WARRANTY; without even the implied warranty of
	; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	; GNU Affero General Public License for more details.
	;
	; You should have received a copy of the GNU Affero General Public License
	; along with DataBallet. If not, see <http://www.gnu.org/licenses/>.
	;

handle(docroot,urlroot)
	;
	; Response handlers that implement a news/blog type of pages.
	; 
	; docroot represent a directory containing some templates used to generate the various pages.
	; urlroot represent the url root that is being handled.  Will be used to create appropriate links.  Default to '/'
	;

	; Support GET and HEAD methods
	quit:'$$methodis^request("GET,HEAD")
	
	; Default urlroot
	if '$data(urlroot) new urlroot set urlroot="/"

	; Return an atom feed for a "/<urlroot>/atom.xml" request,
	; an archive/all posts HTML page for a "/<urlroot>/archive/" request,
	; a specific post HTML page for a "/<urlroot>/posts/<id>" request,
	; and a home HTML page with the latest 5 elements for a "/<urlroot>/" request.
	if request("uri")=(urlroot_"atom.xml") do atomfeed(urlroot)  if 1
	else  if request("uri")=urlroot do main(docroot,urlroot)  if 1
	else  if request("uri")=(urlroot_"archive/") do archive(docroot,urlroot)  if 1
	else  if request("uri")](urlroot_"posts/") do post(docroot)  if 1
	; Everything else is 404 Not Found.
	else  do set^response(404) quit

	; Get md5sum of the generated content.
	do md5sum^response()

	; Validate the cache
	do validatecache^request()

	quit

atomfeed(urlroot)
	;
	; Handle feed request
	;
	new header,author,posts,footer,postid,tag

	; Header
	set header="<?xml version=""1.0"" encoding=""utf-8""?><feed xmlns=""http://www.w3.org/2005/Atom"">"
	set header=header_"<title>"_$get(^NEWS("title"))_"</title>"_"<link href=""http://"_request("headers","HOST")_request("uri")_""" rel=""self"" type=""application/atom+xml"" />"
	set header=header_"<link href=""http://"_request("headers","HOST")_urlroot_""" />"_"<id>http://"_request("headers","HOST")_request("uri")_"</id>"
	
	; Auhor
	set author="<author>"
	set tag=$order(^NEWS("author",""))
	for  quit:tag=""  do
	.	set author=author_"<"_tag_">"_^NEWS("author",tag)_"</"_tag_">"
	.	set tag=$order(^NEWS("author",tag))
	set author=author_"</author>"

	; Posts
	set postid=$order(^NEWS("post",""))
	set posts=""
	set response("lastmod")="0,0"
	for  quit:postid=""  do
	.	set posts=posts_"<entry><title>"_^NEWS("post",postid,"title")_"</title><link href=""http://"_request("headers","HOST")_urlroot_"posts/"_postid_""" />"
	.	set posts=posts_"<id>"_request("headers","HOST")_":"_postid_"</id>"
	.	set posts=posts_"<published>"_$zdate(^NEWS("post",postid,"published"),"YEAR-MON-DD")_"T"_$zdate(^NEWS("post",postid,"published"),"24:60:SS")_"Z</published>"
	.	set posts=posts_"<updated>"_$zdate(^NEWS("post",postid,"updated"),"YEAR-MON-DD")_"T"_$zdate(^NEWS("post",postid,"updated"),"24:60:SS")_"Z</updated>"
	.	set posts=posts_"<summary>"_$get(^NEWS("post",postid,"summary"))_"</summary></entry>"
	.	; Update last modified date if needed.
	.	set:$$isnewer^date(^NEWS("post",postid,"updated"),response("lastmod")) response("lastmod")=^NEWS("post",postid,"updated")
	.	set response("glolist","^NEWS(""post"","_postid_",""updated"")")=""
	.	; Get next post
	.	set postid=$order(^NEWS("post",postid))

	set header=header_"<updated>"_$zdate(response("lastmod"),"YEAR-MON-DD")_"T"_$zdate(response("lastmod"),"24:60:SS")_"Z</updated>"

	; Footer
	set footer="</feed>"

	set response("content")=header_author_posts_footer

	set response("headers","Content-Type")="application/atom+xml"

	quit

main(docroot,urlroot)
	;
	; Handle main page
	;
	new localvar,lastmod

	set response("content")=""
	; Use template engine to load the header of the page.  Convention is to use '<docroot>/start.html', which can include a <title>{%}title{%}</title> line in there
	; to make use of ^NEWS("title")
	set localvar("title")=$get(^NEWS("title"))
	set response("lastmod")=$$loadcontent^template(docroot,docroot_"/start.html")

	; Populate content from database, up to 5 items, if any
	new postid,cnt
	set postid=$order(^NEWS("post",""))
	set cnt=0
	set response("content")=response("content")_"<h2>"_$get(^NEWS("title"))_"</h2>"
	for  quit:postid=""  quit:cnt=5  do
	.	set response("content")=response("content")_"<h3>"_^NEWS("post",postid,"title")_"</h3>"
	.	set response("content")=response("content")_"<p>"_^NEWS("post",postid,"content")_"</p>"
	.	; Update last modified date if needed.
	.	set:$$isnewer^date(^NEWS("post",postid,"updated"),response("lastmod")) response("lastmod")=^NEWS("post",postid,"updated")
	.	set response("glolist","^NEWS(""post"","_postid_",""updated"")")=""
	.	; Get next post
	.	set postid=$order(^NEWS("post",postid))
	.	set cnt=cnt+1

	; Add link to archives (all posts)
	set response("content")=response("content")_"<p>Browse <a href="""_urlroot_"archive/"">older posts</a>.</p>"

	; Use template engine to load the footer of the page.  Convention is to use '<docroot>/end.html'.
	set lastmod=$$loadcontent^template(docroot,docroot_"/end.html")
	; Update last modified date if needed.
	set:$$isnewer^date(lastmod,response("lastmod")) response("lastmod")=lastmod

	; Set response's content type
	set response("headers","Content-Type")="text/html"

	quit

archive(docroot,urlroot)
	;
	; Handle archive page
	;
	new localvar,lastmod

	set response("content")=""
	; Use template engine to load the header of the page.  Convention is to use '<docroot>/start.html', which can include a <title>{%}title{%}</title> line in there
	; to make use of ^NEWS("title")
	set localvar("title")=$get(^NEWS("title"))_" | Archive"
	set response("lastmod")=$$loadcontent^template(docroot,docroot_"/start.html")

	; List all posts from database
	new postid,cnt
	set postid=$order(^NEWS("post",""))
	set cnt=0
	set response("content")=response("content")_"<h2>"_$get(^NEWS("title"))_"</h2><h3>Archive</h3>"
	for  quit:postid=""  do
	.	set response("content")=response("content")_"<a href=""http://"_request("headers","HOST")_urlroot_"posts/"_postid_""">"_^NEWS("post",postid,"title")_"</a><br>"
	.	; Update last modified date if needed.
	.	set:$$isnewer^date(^NEWS("post",postid,"updated"),response("lastmod")) response("lastmod")=^NEWS("post",postid,"updated")
	.	set response("glolist","^NEWS(""post"","_postid_",""updated"")")=""
	.	; Get next post
	.	set postid=$order(^NEWS("post",postid))

	; Use template engine to load the footer of the page.  Convention is to use '<docroot>/end.html'.
	set lastmod=$$loadcontent^template(docroot,docroot_"/end.html")
	; Update last modified date if needed.
	set:$$isnewer^date(lastmod,response("lastmod")) response("lastmod")=lastmod

	; Set response's content type
	set response("headers","Content-Type")="text/html"

	quit

post(docroot)
	;
	; Handle specific post
	;
	new localvar,lastmod,postid

	set postid=$zpiece(request("uri"),"/",4,4)
	if '$data(^NEWS("post",postid)) do set^response(404) quit
	set response("content")=""
	; Use template engine to load the header of the page.  Convention is to use '<docroot>/start.html', which can include a <title>{%}title{%}</title> line in there
	; to make use of ^NEWS("title")
	set localvar("title")=$get(^NEWS("title"))_" | "_^NEWS("post",postid,"title")
	set response("lastmod")=$$loadcontent^template(docroot,docroot_"/start.html")

	; A post from database
	set response("content")=response("content")_"<h2>"_$get(^NEWS("title"))_"</h2>"
	set response("content")=response("content")_"<h3>"_^NEWS("post",postid,"title")_"</h3>"
	set response("content")=response("content")_"<p>"_^NEWS("post",postid,"content")_"</p>"
	; Update last modified date if needed.
	set:$$isnewer^date(^NEWS("post",postid,"updated"),response("lastmod")) response("lastmod")=^NEWS("post",postid,"updated")
	set response("glolist","^NEWS(""post"","_postid_",""updated"")")=""

	; Use template engine to load the footer of the page.  Convention is to use '<docroot>/end.html'.
	set lastmod=$$loadcontent^template(docroot,docroot_"/end.html")
	; Update last modified date if needed.
	set:$$isnewer^date(lastmod,response("lastmod")) response("lastmod")=lastmod

	; Set response's content type
	set response("headers","Content-Type")="text/html"

	quit
