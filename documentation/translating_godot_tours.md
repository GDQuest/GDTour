# Translating Godot tours

Godot Tours leverages internationalization features built into the Godot engine to provide translation support.

You can translate a tour into any language by including translation strings.

To do so, you need to:

1. Use translation functions on every string you want to translate in the tour code.
2. Extract the strings to translate to a translation template file (a POT file).
3. Create a copy of the translation template with translations for your target language (a PO file).
4. Add the PO translation file to the tour in Godot.

Limitations: When we designed the Godot Tours translation system, we thought we would have a single tour per Godot project. As a result, you need to include individual translation files in each tour's source files, even if translations are shared by all tours in the project.

## Using translation functions

For Godot to detect and extract the strings you want to translate, you need to use translation functions in your code.

There is a built-in function called `tr()` in the engine, short for "translate", that you can use in games. However, it does not work well in plugins like Godot Tours. So, we added our own function that the plugin registers, which you need to use: `gtr()`.

Every string you want to translate should be wrapped in this function call, like so:

```gdscript
bubble_add_text([gtr("Welcome to the Godot Tours!"), gtr("This is a tour to help you learn how to use Godot.")])
```

## Extracting the strings to a translation template file

Once all your strings are wrapped in translation function calls, Godot can detect them and extract them to a translation template file: a POT file. This file serves as a template to translate the text to specific languages and to synchronize translations when you add new strings to translate. It's a standard file format for translations called "Portable Object" (PO in short).

To generate a POT file: 

1. Go to Project -> Project Settings...
2. Click the Localization tab.
3. Click the POT Generation sub-tab.
4. For each file in your interactive tour, click the Add... button and add the file.
5. Click the Generate POT button and save the POT file somewhere in your project.

## Create a translation file for the target language

POT files are templates for translations. They contain the original strings to translate, but they don't have the translations themselves. To create a translation file for a specific language, you need to create a PO file.

You can use a program like PoEdit to create a PO file. PoEdit is a free and open-source program to translate files into the Portable Object format. You can download it from [poedit.net](https://poedit.net/).

In PoEdit, click the Create New button to create a PO file from a POT file. It will ask you for the target language. After that, you can translate the strings in the PO file and save it. By default, PoEdit will suggest saving the file using the language code as a name (for example, `ja.po` for Japanese). You can keep this file name.

## Add the PO translation file to the Godot project

Once you have the PO file with the translations, you need to move or copy it to a sub-directory named `locale/` in the directory containing the tour you want to translate. Let's take the open-source tour [101: The Godot Editor](https://github.com/gdquest-demos/godot-tours-101-the-godot-editor) as an example. Its directory path is `res://tours/godot-first-tour/`.

To add the translation file to the project:

1. Create a sub-directory named `locale/` in the tour directory. For the example tour, the path would be `res://tours/godot-first-tour/locale/`.
2. Copy the PO file to the `locale/` directory.

Then, ensure that the editor language is set to the language you want the tour to be in, activate the tour plugin, and restart the Godot editor if needed. Godot Tours will automatically detect the translation file and display the tour in the editor's language.