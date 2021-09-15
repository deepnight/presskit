# Presskit for Haxe

Presskit is a simple Haxe library that generates static HTML presskits from either XML or JSON source files.

 - Use either XML (recommended) or JSON to feed a HTML template.
 - Everything can be customized.
 - Basic **Markdown** is supported: **bold**, *italic*, ~~striked~~, [links](#nope), lists and nested lists.


## Install

You need [Haxe](https://haxe.org) to run this library.

Install the lib:
```
haxelib install presskit
```

Run it in your project folder:
```
haxelib run presskit
haxelib run presskit docs/myPresskit.xml
haxelib run presskit docs/myPresskit.json docs/myTemplate.html
```


## How does it work?

**It's super simple, and designed to be very easy to "extend", as you'll see.**

The XML/JSON is parsed and every entry found in it is given a unique name.

```xml
<game>
	<title> Hello </title> <!-- Entry will be named "game_title" -->
</game>
<company>
	<url> Some link </url> <!-- Entry will be named "company_url" -->
</company>
```

In your HTML template, you may refer to any XML/JSON entry by just using its `%name%`, for example, `%game_title%` or `%company_url%`.

## Live demo

You can see a live example here:

https://deepnight.net/files/presskit/nuclearBlaze/

## Example 

A typical XML file looks like:
```xml
<game>
	<title> Nuclear Blaze </title>

	<url> [Steam page](https://store.steampowered.com/app/1662480) </url>

	<desc>
		<img src="img/keyart.png"/>

		A **unique** 2D firefighting game from the creator of **[Dead Cells](https://deadcells.com)**, with all the devastating backdrafts, exploding walls and sprinklers you could expect.

		- This game is cool,
		- Another bullet point,
		- And a last one.
	</desc>
</game>

<company>
	<name> Deepnight Games </name>
</company>
```

And the corresponding HTML (simplified) template:
```html
<html lang="en">
	<head> [...] </head>

	<body>
		<div class="presskit">
			<h2> %game_title% (by %company_name%)</h2>
			<div class="desc"> %game_desc% </div>
			<div class="desc"> Website: %game_url% </div>
		</div>
	</body>
</html>
```

