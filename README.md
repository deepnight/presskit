# Presskit for Haxe

Presskit is a simple Haxe library that generates static HTML presskits from either XML or JSON source files.

 - Use either XML (recommended) or JSON to feed a HTML template.
 - Everything can be customized.
 - Basic **Markdown** is supported: **bold**, *italic*, ~~striked~~, [links](#nope), lists and nested lists.

You can see an example of a generated presskit here:

https://deepnight.net/files/presskit/nuclearBlaze/


# Install

You need [Haxe](https://haxe.org) to run this library.

Install the lib:
```
haxelib install presskit
```

# Usage

## METHOD 1 - Use the existing default HTML template

Generate an empty Presskit file in your prefered format.

**XML (recommended):**
```
haxelib run presskit -extract myPresskit.xml
```

**JSON:**
```
haxelib run presskit -extract myPresskit.json
```
*Why is XML recommended over JSON in 2021 you might wonder? Simply because the ouput is an HTML file, and XML format is more convenient for this exact purpose.*

Now just edit your presskit file and fill in the fields.

When you're ready to generate your HTML presskit page, run the following command:

```
haxelib run presskit myPresskit.xml [-zip]
```

The optional `-zip` argument will generate a ZIP archive and add a "Download everything as ZIP" to the HTML page.

## METHOD 2 - Create your own HTML template first

Create some HTML file containing variables named like `%productName%`. You might as well copy the existing [Default HTML template](tpl/default.html) and start from here. Don't forget to grab the CSS along with it.

```html
<div class="presskit">
	<h2>Factsheet</h2>
	<dl>
		<dt>Product name</dt>
		<dd>%productName%</dd>

		<dt>Developer</dt>
		<dd>%companyName%</dd>
	</dl>
</div>
```

Run this command to extract all variables (eg. `%productName%`) and build a XML or JSON out of it:

```xml
<productName></productName>
<companyName></companyName>
```

You can then fill this file, and build your HTML final presskit using:

```
haxelib run presskit myPresskitFile.xml myCustomTemplate.html
```

# How does it work?

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

