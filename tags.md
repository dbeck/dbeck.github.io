---
layout: page
title: Tags
permalink: /tags/
nav_exclude: true
---

{% assign sorted_tags = site.tags | sort %}
{% for tag in sorted_tags %}
<h2 id="{{ tag[0] | slugify }}">{{ tag[0] }}</h2>
<ul>
  {% for post in tag[1] %}
  <li><span class="post-date">{{ post.date | date_to_string }}</span> &raquo; <a href="{{ post.url | relative_url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>
{% endfor %}
