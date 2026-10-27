---
layout: page
title: Categories
permalink: /categories/
---

{% assign sorted_categories = site.categories | sort %}
{% for category in sorted_categories %}
<h2 id="{{ category[0] | slugify }}">{{ category[0] }}</h2>
<ul>
  {% for post in category[1] %}
  <li><span class="post-date">{{ post.date | date_to_string }}</span> &raquo; <a href="{{ post.url | relative_url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>
{% endfor %}
