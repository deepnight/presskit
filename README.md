# Presskit for Haxe

Presskit is a simple Haxe library that generates static HTML presskits from either XML or JSON source files.

 - Use either XML (recommended) or JSON to feed a HTML template.
 - Everything can be customized.
 - Basic **Markdown** is supported: **bold**, *italic*, ~~striked~~, [links](#nope), lists and nested lists.

You can see an example of a generated presskit here:

https://deepnight.net/files/presskit/nuclearBlaze/



# Installation

You need [Haxe](https://haxe.org) to run this library.

Install the lib:
```
haxelib install presskit
```



# Usage

## Method 1 - Use the existing default HTML template

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
haxelib run presskit -html myPresskit.xml [-zip]
```

The `-html` indicates to switch to HTML generation mode.

The optional `-zip` argument will generate a ZIP archive and add a "Download everything as ZIP" to the HTML page.

## Method 2 - Create your own HTML template first

### Custom HTML template

Create some HTML file containing variables named like `%productName%`. It's a good idea to start from the existing [default HTML template](tpl/default.html). Don't forget to grab the CSS along with it.

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

### Syntax of HTML template variables

Your variable names can contain `/` (slashes) to create some hierarchy in your presskit file:
```html
<div class="presskit">
	<h2>%product/name%</h2>
	<div class="desc">
		%product/desc%
	</div>
</div>
```

**XML:**
```xml
<product>
	<name></name>
	<desc></desc>
</product>
```

### Build your final HTML presskit

You can then fill this file, and build your HTML final presskit using:

```
haxelib run presskit -html myPresskitFile.xml myCustomTemplate.html
```



# Example

HTML template:
```html
<html lang="en">
	<head> [...] </head>

	<body>
		<div class="presskit">
			<h2> %game/title% (by %company/name%)</h2>
			<div class="desc"> %game/desc% </div>
			<div class="desc"> Website: %game/url% </div>
		</div>
	</body>
</html>
```

Its corresponding XML:
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

Or JSON:
```JSON
{
	"game": {
		"title": "Nuclear Blaze",
		"url": "[Steam page](https://store.steampowered.com/app/1662480)",
		"desc": [
			'<img src="img/keyart.png"/>',
			'A **unique** 2D firefighting game from the creator of **[Dead Cells](...)**, with all the devastating backdrafts, exploding walls and sprinklers you could expect.',

			'- This game is cool',
			'- Another bullet point',
			'- And a last one'
		]
	},
	"company": {
		"name": "Deepnight Games"
	}
}
```
