import arsd.minigui;
import arsd.png;

void main() {
	auto window = new MainWindow("MG Notepad");

	window.icon = readPngFromBytes(import("notepad-icon.png"));

	// we can add widgets before or after setting the menu, either way is fine.
	// i'll do it before here so the local variables are available to the commands.

	auto textEdit = new TextEdit(window);

	// Remember, in D, you can define structs inside of functions
	// and those structs can access the function's local variables.
	//
	// Of course, you might also want to do this separately, and if you
	// do, make sure you keep a reference to the window as a struct data
	// member so you can refer to it in cases like this Exit function.
	struct Commands {
		// the & in the string indicates that the next letter is the hotkey
		// to access it from the keyboard (so here, alt+f will open the
		// file menu)
		@menu("&File") {
			@accelerator("Ctrl+N")
			@hotkey('n')
			@icon(GenericIcons.New) // add an icon to the action
			@toolbar("File") // adds it to a toolbar.
			// The toolbar name is never visible to the user, but is used to group icons.
			void New() {
				previousFileReferenced = null;
				textEdit.content = "";
			}

			@icon(GenericIcons.Open)
			@toolbar("File")
			@hotkey('s')
			@accelerator("Ctrl+O")
			void Open(FileName!() filename) {
				import std.file;
				textEdit.content = std.file.readText(filename);
			}

			@icon(GenericIcons.Save)
			@toolbar("File")
			@accelerator("Ctrl+S")
			@hotkey('s')
			void Save() {
				// these are still functions, so of course you can
				// still call them yourself too
				Save_As(previousFileReferenced);
			}

			// underscores translate to spaces in the visible name
			@hotkey('a')
			void Save_As(FileName!() filename) {
				import std.file;
				std.file.write(previousFileReferenced, textEdit.content);
			}

			// you can put the annotations before or after the function name+args and it works the same way
			@separator
			void Exit() @accelerator("Alt+F4") @hotkey('x') {
				window.close();
			}
		}

		@menu("&Edit") {
			// not putting accelerators here because the text edit widget
			// does it locally, so no need to duplicate it globally.

			@icon(GenericIcons.Undo)
			void Undo() @toolbar("Undo") {
				textEdit.undo();
			}

			@separator

			@icon(GenericIcons.Cut)
			void Cut() @toolbar("Edit") {
				textEdit.cut();
			}
			@icon(GenericIcons.Copy)
			void Copy() @toolbar("Edit") {
				textEdit.copy();
			}
			@icon(GenericIcons.Paste)
			void Paste() @toolbar("Edit") {
				textEdit.paste();
			}

			@separator
			void Select_All() {
				textEdit.selectAll();
			}
		}

		@menu("Help") {
			void About() @accelerator("F1") {
				window.messageBox("A minigui sample program.");
			}

			// @label changes the name in the menu from what is in the code
			@label("In Menu Name")
			void otherNameInCode() {}
		}
	}

	// declare the object that holds the commands, and set
	// and members you want from it
	Commands commands;

	// and now tell minigui to do its magic and create the ui for it!
	window.setMenuAndToolbarFromAnnotatedCode(commands);

	// then, loop the window normally;
	window.loop();

	// important to note that the `commands` variable must live through the window's whole life cycle,
	// or you can have crashes. If you declare the variable and loop in different functions, make sure
	// you do `new Commands` so the garbage collector can take over management of it for you.
}
