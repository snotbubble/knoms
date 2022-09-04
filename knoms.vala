// knoms
// knowledge management system
// by c.p.brown 2022

// long term goal is to wean myself off Houdini for admin work,
// use of which is insane overkill (& a DRM nightmare), but I can't find anything that comes close to its speed & capability
//
// this probably won't be usable until 2023 as there's a massive amount of ui fuckery to sort-out 1st
//
//
// short term goals
//
// - create a simple page/article website:
//
//   nodes                                                 list
//
//                 +---------+                             +-----------------+
//                 | artilce |                             | save            |
//                 +---------+                             +-----------------+
// +-------------+  | +---------+      +-------------+       +---------------+
// | header.html |  | | article |      | footer.html |       | merge         |
// +-------------+  | +---------+      +-------------+       +---------------+
//         \        |  |                 /                     +-------------+
//          \       |  | +---------+    /                      | header.html |
//           \      |  | | article |   /                       +-------------+
//            \     |  | +---------+  /                        +-------------+
//             \    |  |      |      /                         | article     |
//              \   |  |      |     /                          +-------------+
//               \  |  |      |    /                           +-------------+
//               +--------------------+                        | article     |
//               | merge              |                        +-------------+
//               +--------------------+                        +-------------+
//                         |                                   | article     |
//                     +-------+                               +-------------+
//                     | save  |                               +-------------+
//                     +-------+                               | footer.html |
//                                                             +-------------+
//
//
// - link custom parameters, create scripted custom parameters that can use input vals, save/load node parameter loadouts:
//
//    nodes                                                                              list
//
//  +---------+      +----------+          +--------------+  +--------+  +------+   ┌───┬─────────────────────────┐
//  | invoice |      | person   |          | project      |--| script |--| save |   │ - │ save                    │
//  +=========+      +==========+          +==============+  +--------+  +------+   ├───┼───┬─────────────────────┤
//  | total   |------| fees     |      +---| labor        |                         │   │ - │ script              │
//  +---------+     /+----------+     /    +--------------+                         ├ - └───┼───┬─────────────────┤
//  +---------+    / | fees ytd |----+   +-| licenses     |                         │       │ - │ project         │
//  | invoice |   /  +----------+       /  +--------------+                         ├ - - - └───┼───┬─────────────┤
//  +=========+  /     +----------+    +                                            │           │ - │ company     │
//  | total   |-+      | company  |    |                                            ├ - - - - - └───┴───┬─────────┤
//  +---------+        +==========+    |                                            │                   │ invoice │
//                   +-| fees     |    +                                            ├ - - - - - ┌───┬───┴─────────┤
//  +---------+     /  +----------+   /                                             │           │ - │ person      │
//  | invoice |    /   | fees ytd |--+                                              ├ - - - - - └───┴───┬─────────┤
//  +=========+   /    +----------+                                                 │                   │ invoice │
//  | total   |--+                                                                  ├ - - - - - - - - - ├─────────┤
//  +---------+                                                                     │                   │ invoice │
//                                                                                  └───────────────────┴─────────┘
//                                                                                                       
//                                                                                            
// - stash nodes in subnetworks:
//
//  +---------------+   +--------+  +--------------+
//  | library       |+--| filter |--| make website |+
//  |_______________||  +--------+  |______________||
//   +---------------+               +--------------+


// status:
// making the ui...

// todo
// ! = doing it
// ? = needs research (brute-force trial & error)
// dones are removed, unless something depends on it
//
// - [!] finish reflow of params
// - [!] fix node scale issues
// - [ ] make sb color theme for gtksourceview
// - [ ] beastmode layout: 2x vertical paned, output in left, editor in middle, node and params in right horizontal paned
// - [ ] node text scale
// - [ ] add and remove fields per node using code tags: //@[filedname:fieldtype:fielddefaultval:valmin:valmax], where '//' is the language escape char, eg:
//       percent: ;@[percent:float:50.0:0.0:100.0] <- this gets subbed with field val before eval
//       name: ;@[name:tag:<name goes here>]
//       enabled: ;@[ena:bool:false]
//       items: ;@[itm:block:["one" "two" "three"]]
// - [ ] node expand/collapse with custom params
// - [ ] link ports
// - [ ] link drawing
// - [ ] sloppy link and unlink
// - [ ] link data:
//       string       idx : link hash
//       string[]     inp : link input (node hash)
//       string[]     oup : link output (node hash)
//       string       col : link color
//       double       fat : link width
//       string       typ : link type: parameter or node
// - [ ] link selection

using Gtk;

string selectednode;

// data containers

struct customfield {
	public string	nom;
	public string	val;
	public string	typ;
}

struct params {
	public customfield[]	fld;
}

struct knode {
	string      nom;	// node name
	string      typ;	// node type: "Load", "Save", "Merge", "ForEach", "Switch", "Sequence", "Join", "Script"
	string      src;	// source code
	string		cex;	// srouce type: "text" "html" "xml" "rebol" "python" "sh" "vala"
	string		lod;	// file to load/save, if type == 0 or 1
	string		lex;	// type of the above
	string      pre;	// preset file
	bool        hoi;	// node enbled
	bool        frz;	// node frozen (cahced)
	string      idx;	// node hash
	string[]    oup;	// node outputs (of node hashes), used to build a list for multi-select and highlighting
	string[]    inp;	// node inputs (of node hashes), used to build a list for eval
	string      res;	// node result (if cached)
	string		rex;	// result type
	double      pox;	// node position x, from top-left corner
	double      poy;	// node position y
	bool        ste;	// node state: false = unselected, true = selected
	bool        hil;	// node highlight state
	string		col;	// node tint color
	params[]    cpa;	// custom parameters
}

// globals - these are used everywhere

bool			doup;		// toggle event signals
knode?[] 		allknodes;	// node list

// some commonly used functions

string getfilenamefile (string f) {
	if (f != null) {
		if (f.strip() != "") { 
			string[] fp = f.strip().split("/");
			if (fp.length > 1) {
				string[] pp = fp[(fp.length - 1)].split(".");
				return pp[0];
			}
		}
	}
	return "";
}
string getfileext (string f) {
	if (f != null) {
		if (f.strip() != "") { 
			string[] fp = f.strip().split("/");
			if (fp.length > 1) {
				string[] pp = fp[(fp.length - 1)].split(".");
				return pp[(pp.length - 1)];
			}
		}
	}
	return "";
}
File getfiledir (string f) {
	string o = "";
	File x = File.new_for_path(o);
	if (f != null) {
		if (f.strip() != "") { 
			string[] fp = f.strip().split("/");
			if (fp.length > 1) {
				for (int l = 0; l < (fp.length - 1); l++) {
					o = o.concat(fp[l],"/");
				}
			}
			x = File.new_for_path(o);
			return x;
		}
	}
	return x;
}

// custom field classes

public class EntryField : Gtk.Box {
	private Gtk.Label ll;
	private Gtk.Entry ee;
	private Gtk.CssProvider ttshade;
	public EntryField (string nn, string vv, int s, int p, int f) {
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		ll = new Gtk.Label(null);
		ll.set_markup("<span foreground=\"#FFFFFF88\"><b><big>%s</big></b></span>".printf(nn));
		ee = new Gtk.Entry();
		ee.text = vv;
		this.append(ll);
		this.append(ee);

		ll.margin_top = 20;
		ll.margin_end = 10;
		ll.margin_start = 10;
		ll.margin_bottom = 0;
		ee.margin_top = 10;
		ee.margin_end = 10;
		ee.margin_start = 10;
		ee.margin_bottom = 10;
		this.margin_bottom = 10;

		ttshade = new Gtk.CssProvider();
		string ttcss = ".xx { background: #00000040; box-shadow: 2px 2px 2px #00000066;}";
		ttshade.load_from_data(ttcss.data);
		this.get_style_context().add_provider(ttshade, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		this.get_style_context().add_class("xx");

		ee.changed.connect(() => {
			if (doup) {
				if (ee.text != null) {
					doup = false;
					allknodes[s].cpa[p].fld[f].val = ee.text.strip();
					doup = true;
				}
			}
		});
	}
}



public class TextViewField : Gtk.Box {
	private Gtk.Label ll;
	private Gtk.TextView ee;
	private Gtk.ScrolledWindow eescrol;
	private Pango.TabArray eetab;
	private Gtk.CssProvider ttshade;
	public TextViewField (string nn, string vv, int s, int p, int f) {
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		ll = new Gtk.Label(null);
		ll.set_markup("<span foreground=\"#FFFFFF88\"><b><big>%s</big></b></span>".printf(nn));
		ee = new Gtk.TextView();
		ee.buffer.set_text(vv);
		ee.accepts_tab = true;
		ee.set_monospace(true);
		var pgcx = ee.get_pango_context();
		int tabw = pgcx.get_metrics(pgcx.get_font_description(), pgcx.get_language()).get_approximate_digit_width();
		tabw = ((int) (Pango.units_to_double(tabw) * 4.0)) + 1;
		eetab = new Pango.TabArray(1, true);
		eetab.set_tab(0, LEFT, tabw);
		ee.set_tabs(eetab);
		ee.vexpand = true;
		ee.top_margin = 10;
		ee.left_margin = 10;
		ee.right_margin = 10;
		ee.bottom_margin = 10;
		eescrol = new Gtk.ScrolledWindow();
		eescrol.set_child(ee);
		this.append(ll);
		this.append(eescrol);
		eescrol.height_request = 200;

		ll.margin_top = 20;
		ll.margin_end = 10;
		ll.margin_start = 10;
		ll.margin_bottom = 0;
		ee.margin_top = 10;
		ee.margin_end = 10;
		ee.margin_start = 10;
		ee.margin_bottom = 10;
		this.margin_bottom = 10;

		ttshade = new Gtk.CssProvider();
		string ttcss = ".xx { background: #00000040; box-shadow: 2px 2px 2px #00000066;}";
		ttshade.load_from_data(ttcss.data);
		this.get_style_context().add_provider(ttshade, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		this.get_style_context().add_class("xx");

		ee.buffer.changed.connect(() => {
			if (doup) {
				if (ee.buffer.text != null) {
					doup = false;
					allknodes[s].cpa[p].fld[f].val = ee.buffer.text.escape();
					doup = true;
				}
			}
		});
	}
}

public class ImageField : Gtk.Box {
	private Gtk.Label ll;
	private Gtk.Picture ee;
	private Gtk.Label ss;
	private Gtk.MenuButton bb;
	private Gtk.Box cc;
	private Gtk.Popover lpop;
	private Gtk.Box lbox;
	private Gtk.GestureClick bb_click;
	private Gtk.CssProvider ccshade;
	private Gtk.CssProvider ttshade;
	private GLib.Dir dcr;
	public ImageField (string nn, string vv, int s, int p, int f) {
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		this.hexpand = false;
		ll = new Gtk.Label(null);
		ll.set_markup("<span foreground=\"#FFFFFF88\"><b><big>%s</big></b></span>".printf(nn));
		ee = new Gtk.Picture();
		cc = new Gtk.Box(HORIZONTAL,10);
		ss = new Gtk.Label(null);
		ss.set_markup("<span foreground=\"#FFFFFF88\"><b>%s</b></span>".printf(vv));
		ss.hexpand = true;
		lbox = new Gtk.Box(VERTICAL,5);
		lbox.margin_start = 5;
		lbox.margin_end = 5;
		lbox.margin_top = 5;
		lbox.margin_bottom = 5;
		lpop = new Gtk.Popover();
		bb = new Gtk.MenuButton();
		bb.icon_name = "document-open-symbolic";
		ee.can_shrink = true;
		ee.keep_aspect_ratio = true;
		ee.set_filename(vv);

		cc.margin_top = 0;
		cc.margin_end = 10;
		cc.margin_start = 10;
		cc.margin_bottom = 10;
		ee.margin_top = 0;
		ee.margin_end = 10;
		ee.margin_start = 10;
		ee.margin_bottom = 0;
		ll.margin_top = 20;
		ll.margin_end = 10;
		ll.margin_start = 10;
		ll.margin_bottom = 0;
		this.margin_bottom = 10;
		ee.height_request = 180;
		ee.width_request = 180;

		lpop.set_child(lbox);
		bb.popover = lpop;
		cc.append(ss);
		cc.append(bb);
		this.append(ll);
		this.append(ee);
		this.append(cc);

		ccshade = new Gtk.CssProvider();
		string cccss = ".xx { background: #00000020; }";
		ccshade.load_from_data(cccss.data);
		ss.get_style_context().add_provider(ccshade, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		ss.get_style_context().add_class("xx");

		ttshade = new Gtk.CssProvider();
		string ttcss = ".xx { background: #00000040; box-shadow: 2px 2px 2px #00000066;}";
		ttshade.load_from_data(ttcss.data);
		this.get_style_context().add_provider(ttshade, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		this.get_style_context().add_class("xx");

		bb_click = new Gtk.GestureClick();
		bb.add_controller(bb_click);
		bb_click.pressed.connect(() => {
			if (doup) {
				doup = false;
				while (lbox.get_first_child() != null) {
					lbox.remove(lbox.get_first_child());
				}
				var pth = GLib.Environment.get_current_dir();
				pth = pth.concat("/src");
				print("source path is %s\n",pth);
				try { dcr = Dir.open (pth, 0); } catch (Error e) { print("%s\n",e.message); }
				string? name = null;
				while ((name = dcr.read_name ()) != null) {
					var exts = name.split(".");
					if (exts.length == 2) {
						if (exts[1] == "png" || exts[1] == "jpg") {
							Gtk.Button muh = new Gtk.Button.with_label (name);
							lbox.append(muh);
							muh.clicked.connect ((buh) => {
								var nm = buh.label;
								string ff = Path.build_filename ("./src/", nm);
								print("selected file is: %s\n",ff);
								ee.set_filename(ff);
								ss.set_markup("<span foreground=\"#FFFFFF88\"><b>%s</b></span>".printf(ff));
								allknodes[s].cpa[p].fld[f].val = ff;
								lpop.popdown();
							});
						}
					}
				}
				doup = true;
			}
		});
	}
}

public class EntryButtonField : Gtk.Box {
	private Gtk.Label ll;
	private Gtk.Entry ee;
	private Gtk.MenuButton bb;
	private Gtk.Box cc;
	private Gtk.Popover lpop;
	private Gtk.Box lbox;
	private Gtk.GestureClick bb_click;
	private Gtk.CssProvider ttshade;
	private GLib.Dir dcr;
	public EntryButtonField (string nn, string vv, int s, int p, int f) {
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		this.vexpand = false;
		ll = new Gtk.Label(null);
		ll.set_markup("<span foreground=\"#FFFFFF88\"><b><big>%s</big></b></span>".printf(nn));
		ee = new Gtk.Entry();
		ee.hexpand = true;
		cc = new Gtk.Box(HORIZONTAL,10);
		lbox = new Gtk.Box(VERTICAL,2);
		lbox.margin_start = 5;
		lbox.margin_end = 5;
		lbox.margin_top = 5;
		lbox.margin_bottom = 5;
		lpop = new Gtk.Popover();
		bb = new Gtk.MenuButton();
		bb.icon_name = "document-open-symbolic";
		ee.text = vv;
		cc.margin_top = 10;
		cc.margin_end = 10;
		cc.margin_start = 10;
		cc.margin_bottom = 10;
		ll.margin_top = 20;
		ll.margin_end = 10;
		ll.margin_start = 10;
		ll.margin_bottom = 0;
		this.margin_bottom = 10;

		lpop.set_child(lbox);
		bb.popover = lpop;
		cc.append(ee);
		cc.append(bb);
		this.append(ll);
		this.append(cc);

		ttshade = new Gtk.CssProvider();
		string ttcss = ".xx { background: #00000040; box-shadow: 2px 2px 2px #00000066;}";
		ttshade.load_from_data(ttcss.data);
		this.get_style_context().add_provider(ttshade, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		this.get_style_context().add_class("xx");

		bb_click = new Gtk.GestureClick();
		bb.add_controller(bb_click);
		bb_click.pressed.connect(() => {
			if (doup) {
				doup = false;
				while (lbox.get_first_child() != null) {
					lbox.remove(lbox.get_first_child());
				}
				var pth = GLib.Environment.get_current_dir();
				pth = pth.concat("/src");
				print("source path is %s\n",pth);
				try { dcr = Dir.open (pth, 0); } catch (Error e) { print("%s\n",e.message); }
				string? name = null;
				while ((name = dcr.read_name ()) != null) {
					var exts = name.split(".");
					if (exts.length == 2) {
						if (exts[1] == "pdf" || exts[1] == "mp4") {
							Gtk.Button muh = new Gtk.Button.with_label (name);
							lbox.append(muh);
							muh.clicked.connect ((buh) => {
								var nm = buh.label;
								string ff = Path.build_filename ("./src/", nm);
								print("selected file is: %s\n",ff);
								ee.text = ff;
								allknodes[s].cpa[p].fld[f].val = ff;
								lpop.popdown();
							});
						}
					}
				}
				doup = true;
			}
		});
	}
}

// dresscode

public class knoms : Gtk.Application {
	construct {
		application_id = "com.cpbrown.knoms";
		flags = ApplicationFlags.FLAGS_NONE;
	}
}

public class hnwin : Gtk.ApplicationWindow {
	private bool thf;
	private bool twf;
	private bool tnf;
	private bool amdesktop;
	private bool amphone;
	private bool ambeastmode;
	private int winx;
	private int winy;
	private Gtk.Box firstbox;
	private Gtk.Box secondbox;
	private Gtk.Box thirdbox;
	private Gtk.Box firstrow;
	private Gtk.Box secondrow;
	private Gtk.Box thirdrow;
	private Gtk.DropDown oplist;
	private Gtk.Entry nameentry;
	private Gtk.ToggleButton enabledbutton;
	private Gtk.ToggleButton freezebutton;
	private Gtk.Entry fileentry;
	private Gtk.Entry presetentry;
	private GtkSource.View srctext;
	private string extname (string e) {
		string o = "html";
		switch (e) {
			case "txt"	: o = "text"; break;
			case "htm"	: o = "html"; break;
			case "py"	: o = "python"; break;
			case "r3"	: o = "rebol"; break;
			case "r"	: o = "rebol"; break;
			case "reb"	: o = "rebol"; break;
			case "sh"	: o = "sh"; break;
			case "xml"	: o = "xml"; break;
			case "org"	: o = "orgmode"; break;
			default		: o = "html"; break;
		}
		return o;
	}
	private string exttype (string e) {
		string o = "html";
		switch (e) {
			case "text"		: o = "txt"; break;
			case "html"		: o = "html"; break;
			case "python"	: o = "py"; break;
			case "rebol"	: o = "r3"; break;
			case "sh"		: o = "sh"; break;
			case "xml"		: o = "xml"; break;
			case "orgmode"	: o = "org"; break;
			default			: o = "html"; break;
		}
		return o;
	}
	private void reflowparams (int sx) {

// cause flowbox is just a shitty nxn grid

		if (thf) {
			if (sx > (thirdbox.width_request + secondbox.width_request)) {
				var th = thirdrow.get_last_child();
				thirdrow.remove(th);
				secondrow.append(th);
				thf = false;
			}
		}
		if (twf) {
			if (sx > (firstbox.width_request + secondbox.width_request)) {
				var tw = secondrow.get_first_child();
				secondrow.remove(tw);
				firstrow.append(tw);
				twf = false;
			}
		}
		if (tnf) {
			if (sx > (firstbox.width_request + secondbox.width_request + thirdbox.width_request)) {
				var tn = secondrow.get_first_child();
				secondrow.remove(tn);
				firstrow.append(tn);
				tnf = false;
			}
		}
		if ((sx - 40) < (firstbox.width_request + secondbox.width_request + thirdbox.width_request)) {
			if (tnf == false) {
				var tn = firstrow.get_last_child();
				firstrow.remove(tn);
				secondrow.append(tn);
				tnf = true;
			}
		}
		if ((sx - 40) < (firstbox.width_request + secondbox.width_request)) {
			if (twf == false) {
				var tn = firstrow.get_last_child();
				firstrow.remove(tn);
				tn.insert_before(secondrow,secondrow.get_first_child());
				twf = true;
			}
		}
		if ((sx - 40) < (secondbox.width_request + thirdbox.width_request)) {
			if (thf == false) {
				var tn = secondrow.get_last_child();
				secondrow.remove(tn);
				thirdrow.append(tn);
				thf = true;
			}
		}
	}
	private int getoplistindex (string t) {
		int o = 0;
		Gtk.Widget ch = oplist.get_last_child().get_first_child().get_first_child().get_last_child().get_first_child().get_first_child();
		int i = 0;
		while(ch != null) {
			var ll = ((Gtk.Label) ch.get_first_child().get_first_child());
			if (ll.label == t) { o = i; break; }
			ch = ch.get_next_sibling();
			i = i + 1;
		}
		return o;
	}
	private void selectnode (string x) {
		if (allknodes.length > 0) {
			if (x != null) {
				if (x != "none") {
					int n = 0;
					for( int i = 0; i < allknodes.length; i++) {
						if (allknodes[i].idx == x) { n = i; break; }
					}
					doup = false;
					print("old selected node is: %s\n",selectednode);
					selectednode = allknodes[n].idx;
					print("new selected node is: %s\n",selectednode);
					if (allknodes[n].nom != null) {
						nameentry.text = allknodes[n].nom;
					}
					if (allknodes[n].lod != null) {
						fileentry.text = allknodes[n].lod;
					}
					if (allknodes[n].pre != null) {
						presetentry.text = allknodes[n].pre;
					}
					if (allknodes[n].typ != null) {
						int styp = getoplistindex(allknodes[n].typ);
						oplist.set_selected(styp);
					}
					if (allknodes[n].nom != null) {
						enabledbutton.active = allknodes[n].hoi;
					}
					if (allknodes[n].nom != null) {
						freezebutton.active = allknodes[n].frz;
					}
					if (allknodes[n].src != null) {
						srctext.buffer.set_text(allknodes[n].src);
					}
					doup = true;
				}
			}
		}
	}
	private int getselectednode ( string x ) {
		if (allknodes.length > 0) {
			if (x != null) {
				if (x != "none") {
					for( int i = 0; i < allknodes.length; i++) {
						if (allknodes[i].idx == x) { return i; }
					}
				}
			}
		}
		return 0;
	}
	public hnwin (Gtk.Application knoms) {Object (application: knoms);}
	construct {

		doup = false;
		thf = true;
		twf = true;
		tnf = true;
		amphone = true;
		amdesktop = false;
		ambeastmode = false;
		selectednode = "none";

// named colors

		string pagebg = "#6B3521FF";		// zn orange
		string pagefg = "#BD4317FF";
		string artcbg = "#112633FF";		// sb blue
		string artcfg = "#1A3B4FFF";

		string bod_hi = "#5FA619FF";		// green
		string bod_lo = "#364F1DFF";

		string tal_hi = "#14A650FF";		// turqoise
		string tal_lo = "#1D5233FF";

		string sbbackground = "#112633FF";	// sb blue
		string sbselect = "#327299FF";
		string sblines = "#08131AFF";
		string sblight = "#19394DFF";
		string sbshade = "#0C1D26FF";
		string sbentry = "#0E232EFF";

		string out_hi = "#8738A1FF";		// purple
		string out_lo = "#351C3DFF";

// interaction states

		bool	izom = false;	// zoom mode
		bool	ipan = false;	// pan mode
		bool	iscr = false;	// scroll mode
		bool	ipik = false;	// pick mode
		bool	igrb = false;	// grab mode
		int		drwm = 0;		// what to draw: 0 = nodes, 1 = list
		bool	dosel = false;	// select a node

// graph memory

		double[] 	ng_moom = {0.0,0.0};		// graph live mousemove xy
		double[] 	ng_mdwn = {0.0,0.0};		// graph live mousedown xy
		double[] 	ng_ogsz = {300.0,300.0};	// graph static size xy - does not change
		double[] 	ng_olsz = {300.0,300.0};	// graph pre-draw size xy - is changed
		double[] 	ng_olof = {0.0,0.0};		// graph pre-draw offset xy
		double[] 	ng_olmd = {0.0,0.0};		// graph pre-draw mousedown xy
		double		ng_olbh = 30.0;				// graph pre-draw bar height
		double 		ng_posx = 0.0;				// graph post-draw offset x
		double 		ng_posy = 0.0;				// graph post_draw offset y
		double		ng_sizx	= 0.0;				// graph post-draw size x
		double		ng_sizy = 0.0;				// graph post-draw size y 
		double 		ng_trgx	= 0.0;				// graph post-draw mousedown x
		double 		ng_trgy = 0.0;				// graph post-draw moudedown y
		double 		ng_barh = 30.0;				// graph row height
		int 		ng_rule = 0;				// graph selected rule
		double[]	ng_rssz = {300.0,300.0};	// graph pre-draw size memory for isolate
		double[]	ng_rsof = {40.0,20.0};		// graph pre-draw offset memory for isolate
		int			ng_node = 0;				// graph selected node list position
		double		ng_nox = 0.0;				// node x pos
		double		ng_noy = 0.0;				// node y pos

// window

		this.title = "knoms";
		this.close_request.connect((e) => {
			return false; 
		});

// header

		print("building headerbar...\n");
		Gtk.Label titl = new Gtk.Label("knoms");
		Gtk.HeaderBar tbar = new Gtk.HeaderBar();
		tbar.show_title_buttons  = false;
		tbar.set_title_widget(titl);
		this.set_titlebar (tbar);
		this.set_default_size(360, (720 - 46));  // magic number for headerbar, since we can't read it yet
		
// headerbr buttons

		Gtk.Button dsav = new Gtk.Button.with_label("save");
		Gtk.Button dpub = new Gtk.Button.with_label("eval");
		tbar.pack_start(dsav);
		tbar.pack_end(dpub);

// node parameters

		print("building node parameters...\n");
		nameentry = new Gtk.Entry();
		nameentry.hexpand = true;
		nameentry.changed.connect(() => {
			if (doup) {
				doup = false;
				if (nameentry.text != null) {
					if (nameentry.text.strip() != "") {
						int sidx = getselectednode(selectednode);
						allknodes[sidx].nom = nameentry.text;
					}
				}
				doup = true;
			}
		});

		oplist = new Gtk.DropDown(null,null);
		oplist.set_model(new Gtk.StringList({"Load", "Save", "Merge", "ForEach", "Switch", "Sequence", "Join", "Script"}));
		oplist.set_selected(0);
		oplist.notify["selected"].connect(() => {
			if (doup) {
				doup = false;
				var n = oplist.get_selected();
				int sidx = getselectednode(selectednode);
				allknodes[sidx].typ = ((StringObject?) oplist.selected_item).string;
				doup = true;
			}
		});

		freezebutton = new Gtk.ToggleButton();
		freezebutton.icon_name = "system-lock-screen";
		freezebutton.set_active(false);
		freezebutton.toggled.connect(() => {
			print("freezebutton toggled: %s\n",freezebutton.active.to_string());
		});

		enabledbutton = new Gtk.ToggleButton();
		enabledbutton.set_active(true);
		Gtk.CssProvider enabledcsp = new Gtk.CssProvider();
		string enabledcss = ".xx { background: #00FF0020; }";
		enabledbutton.get_style_context().add_provider(enabledcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		enabledbutton.get_style_context().add_class("xx");
		enabledcsp.load_from_data(enabledcss.data);
		enabledbutton.icon_name = "media-playback-start";
		enabledbutton.toggled.connect(() => {
			if (doup) {
				doup = false;
				int sidx = getselectednode(selectednode);
				allknodes[sidx].hoi = enabledbutton.active;
				if (enabledbutton.active) { 
					enabledcss = ".xx { background: #00FF0020; }";
					enabledcsp.load_from_data(enabledcss.data);
					enabledbutton.icon_name = "media-playback-start";
				} else { 
					enabledcss = ".xx { background: #AA000040; }";
					enabledcsp.load_from_data(enabledcss.data);
					enabledbutton.icon_name = "media-playback-pause";
				}
				doup = true;
			}
		});

		Gtk.ToggleButton foldbutton = new Gtk.ToggleButton.with_label("+");
		foldbutton.set_active(false);

// node param containers

		print("building node parameter containers...\n");
		Gtk.Box paramscrollbox = new Gtk.Box(VERTICAL,10);
		Gtk.ScrolledWindow paramscroll = new Gtk.ScrolledWindow();
		Gtk.Box headbox = new Gtk.Box(HORIZONTAL,10);
		headbox.margin_top = 0;
		headbox.margin_end = 0;
		headbox.margin_start = 0;
		headbox.margin_bottom = 0;

		firstbox = new Gtk.Box(HORIZONTAL,0);
		secondbox = new Gtk.Box(HORIZONTAL,0);
		thirdbox = new Gtk.Box(HORIZONTAL,0);

		firstbox.append(nameentry);
		firstbox.append(foldbutton);

		secondbox.append(oplist);
		thirdbox.append(freezebutton);
		thirdbox.append(enabledbutton);

		firstbox.width_request = 150;
		secondbox.width_request = 80;
		thirdbox.width_request = 150;

		firstrow = new Gtk.Box(HORIZONTAL,0);
		secondrow = new Gtk.Box(HORIZONTAL,0);
		thirdrow = new Gtk.Box(HORIZONTAL,0);

		firstrow.append(firstbox);
		secondrow.append(secondbox);
		thirdrow.append(thirdbox);	

		secondrow.margin_top = 0;
		secondrow.margin_end = 0;
		secondrow.margin_start = 0;
		secondrow.margin_bottom = 0;

		thirdrow.margin_top = 0;
		thirdrow.margin_end = 0;
		thirdrow.margin_start = 0;
		thirdrow.margin_bottom = 0;

		Gtk.Box headflow = new Gtk.Box(VERTICAL,0);
		headflow.append(firstrow);
		headflow.append(secondrow);
		headflow.append(thirdrow);
		headflow.margin_top = 10;
		headflow.margin_end = 10;
		headflow.margin_start = 10;
		headflow.margin_bottom = 10;

		headbox.append(headflow);

// containers: file for load/save

		print("building node filebox parameters...\n");
		Gtk.Box filebox = new Gtk.Box(HORIZONTAL,5);
		fileentry = new Gtk.Entry();
		fileentry.hexpand = true;
		Gtk.CssProvider fesp = new Gtk.CssProvider();
		string fess = ".xx { background: #00000010; }";
		fesp.load_from_data(fess.data);
		fileentry.get_style_context().add_provider(fesp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		fileentry.get_style_context().add_class("xx");	
		fileentry.changed.connect(() => {
			if (doup) {
				doup = false;
				int sidx = getselectednode(selectednode);
				allknodes[sidx].cex = "sh";
				File lodfile = getfiledir(fileentry.text);
				print("lodfile is %s\n",lodfile.get_path());
				if (lodfile.query_exists() == true) {
					allknodes[sidx].lod = fileentry.text;
					allknodes[sidx].lex = getfileext(fileentry.text);
					allknodes[sidx].rex = allknodes[sidx].lex;
					fess = ".xx { background: #00FF0020; }";
					fesp.load_from_data(fess.data);
				} else {
					fess = ".xx { background: #FF000020; }";
					fesp.load_from_data(fess.data);	
				}
				doup = true;
			}
		});
		Gtk.MenuButton filebutton = new Gtk.MenuButton();
		filebutton.icon_name = "document-open-symbolic";
		Gtk.Popover filepop = new Gtk.Popover();
		filepop.has_arrow = false;
		Gtk.Box filepopbox = new Gtk.Box(VERTICAL,5);
		Gtk.ScrolledWindow filepopscroll = new Gtk.ScrolledWindow();
		filepopbox.margin_top = 5;
		filepopbox.margin_end = 5;
		filepopbox.margin_start = 5;
		filepopbox.margin_bottom = 5;
		filepopscroll.set_child(filepopbox);
		filepop.width_request = 300;
		int wwx, wwy = 0;
		this.get_default_size(out wwx,out wwy);
		filepop.height_request = (wwy - 200);
		filepop.set_child(filepopscroll);
		filebutton.popover = filepop;
		Gtk.GestureClick fileclick = new Gtk.GestureClick();
		filebutton.add_controller(fileclick);
		fileclick.pressed.connect(() => {
			if (doup) {
				doup = false;
				while (filepopbox.get_first_child() != null) {
					filepopbox.remove(filepopbox.get_first_child());
				}
				string scandir = "source";
				int sidx = getselectednode(selectednode);
				if (allknodes[sidx].typ == "Save") { scandir = "output"; }
				string pth = GLib.Environment.get_current_dir();
				File srcpath = File.new_for_path (pth.concat("/",scandir,"/"));
				if (srcpath.query_exists() == false) { srcpath.make_directory_with_parents(); }
				bool allgood = true;
				GLib.Dir dcr = null;
				try { dcr = Dir.open (srcpath.get_path(), 0); } catch (Error e) { print("%s\n",e.message); allgood = false; }
				if (allgood) {
					Gtk.CssProvider mubcsp = new Gtk.CssProvider();
					string mubcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sblight,sbselect);
					mubcsp.load_from_data(mubcss.data);
					string? name = null;
					while ((name = dcr.read_name ()) != null) {
						string[] exts = name.split(".");
						if (exts.length == 2) {
							if (exts[1].strip() != "" ) {
								Gtk.Button muh = new Gtk.Button.with_label (name);
								muh.get_style_context().add_provider(mubcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
								muh.get_style_context().add_class("xx");
								filepopbox.append(muh);
								muh.clicked.connect ((buh) => {
									string nm = buh.label;
									string fff = "./".concat(scandir,"/", nm);
									File og = File.new_for_path(fff);
									fileentry.text = fff;
									allknodes[sidx].lod = fff;
									allknodes[sidx].lex = extname(exts[1]);
									allknodes[sidx].src = "cat %s".printf(fff);
									allknodes[sidx].cex = "sh";
									allknodes[sidx].rex = allknodes[sidx].lex;
									try {
										uint8[] c; string e;
										og.load_contents (null, out c, out e);
										allknodes[sidx].res = ((string) c);
										fess = ".xx { background: #00FF0020; }";
										fesp.load_from_data(fess.data);
									} catch (Error e) {
										print ("failed to read %s: %s\n", og.get_path(), e.message);
										fess = ".xx { background: #FF000020; }";
										fesp.load_from_data(fess.data);	
									}
									filepop.popdown();
								});
							}
						}
					}
				}
				doup = true;
			}
		});
		filebox.append(fileentry);
		filebox.append(filebutton);
		filebox.margin_top = 10;
		filebox.margin_end = 10;
		filebox.margin_start = 10;
		filebox.margin_bottom = 10;

// containers: preset

		print("building node preset box...\n");
		Gtk.Box presetbox = new Gtk.Box(HORIZONTAL,5);
		presetentry = new Gtk.Entry();
		presetentry.hexpand = true;
		Gtk.MenuButton presetbutton = new Gtk.MenuButton();
		presetbutton.icon_name = "document-open-symbolic";
		Gtk.Button presetsave = new Gtk.Button();
		presetsave.icon_name = "document-save-symbolic";
		presetsave.clicked.connect(() => {
			if (presetentry.text.strip() != "") {
				var pth = GLib.Environment.get_current_dir();
				var prepth = File.new_for_path (pth.concat("/presets/"));
				if (prepth.query_exists() == false) { prepth.make_directory_with_parents(); }
				bool allgood = true;
				if (prepth.query_exists() == false) { allgood = false; print("error: couldn't make presets dir...\n"); }
				int sidx = getselectednode(selectednode);
				if (allgood) {
					string lll = "sh";
					allknodes[sidx].cex = ((StringObject?) oplist.selected_item).string;
					print("selected preset type is: %s\n", allknodes[sidx].cex);
					lll = exttype(allknodes[sidx].cex);
					string nm = presetentry.text.strip().replace(" ","_");
					string nme = nm.concat(".",lll);
					string fff = Path.build_filename ("./presets/",nme);
					allknodes[sidx].pre = fff;
					File ooo = File.new_for_path(fff);
					FileOutputStream sss = ooo.replace(null, false, FileCreateFlags.PRIVATE);
					try {
						sss.write(allknodes[sidx].src.data);
					} catch (Error e) { print("failed to write preset: %s\n",e.message); }
				} else { allknodes[sidx].pre = ""; }
			}
		});
		Gtk.Popover presetpop = new Gtk.Popover();
		presetpop.has_arrow = false;
		Gtk.Box presetpopbox = new Gtk.Box(VERTICAL,5);
		Gtk.ScrolledWindow presetpopscroll = new Gtk.ScrolledWindow();
		presetpopbox.margin_top = 5;
		presetpopbox.margin_end = 5;
		presetpopbox.margin_start = 5;
		presetpopbox.margin_bottom = 5;
		presetpopscroll.set_child(presetpopbox);
		presetpop.width_request = 300;
		wwx = 0; wwy = 0;
		this.get_default_size(out wwx,out wwy);
		presetpop.height_request = (wwy - 200);
		presetpop.set_child(presetpopscroll);
		presetbutton.popover = presetpop;
		Gtk.GestureClick presetclick = new Gtk.GestureClick();
		presetbutton.add_controller(presetclick);
		presetclick.pressed.connect(() => {
			if (doup) {
				doup = false;
				while (presetpopbox.get_first_child() != null) {
					presetpopbox.remove(presetpopbox.get_first_child());
				}
				int sidx = getselectednode(selectednode);
				allknodes[sidx].cex = ((StringObject?) oplist.selected_item).string;
				print("selected preset type is: %s\n", allknodes[sidx].cex);
				string presetext = exttype(allknodes[sidx].cex);
				var pth = GLib.Environment.get_current_dir();
				var prepth = File.new_for_path (pth.concat("/presets/"));
				if (prepth.query_exists() == false) { prepth.make_directory_with_parents(); }
				bool allgood = true;
				GLib.Dir dcr = null;
				try { dcr = Dir.open (prepth.get_path(), 0); } catch (Error e) { print("%s\n",e.message); allgood = false; }
				if (allgood) {
					Gtk.CssProvider mubcsp = new Gtk.CssProvider();
					string mubcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sblight,sbselect);
					mubcsp.load_from_data(mubcss.data);
					string? name = null;
					print("searching for files in %s\n",((string) prepth.get_path()));
					while ((name = dcr.read_name ()) != null) {
						var exts = name.split(".");
						if (exts.length == 2) {
							print("checking file: %s\n", name);
							if (exts[1] == presetext) {
								Gtk.Button muh = new Gtk.Button.with_label (name);
								muh.get_style_context().add_provider(mubcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
								muh.get_style_context().add_class("xx");
								presetpopbox.append(muh);
								muh.clicked.connect ((buh) => {
									var nm = buh.label;
									string fff = Path.build_filename ("./presets/", nm);
									File og = File.new_for_path(fff);
									print("selected file is: %s\n",fff);
									string[] nameparts = nm.split(".");
									presetentry.text = nameparts[0];
									try {
										uint8[] c; string e;
										og.load_contents (null, out c, out e);
										srctext.buffer.text = (string) c;
										allknodes[sidx].src = ((string) c);
										allknodes[sidx].pre = fff;
									} catch (Error e) {
										print ("failed to read %s: %s\n", og.get_path(), e.message);
									}
									presetpop.popdown();
								});
							}
						}
					}
				}
				doup = true;
			}
		});
		presetbox.append(presetbutton);
		presetbox.append(presetentry);
		presetbox.append(presetsave);
		presetbox.hexpand = true;

		presetbox.margin_top = 10;
		presetbox.margin_end = 10;
		presetbox.margin_start = 10;
		presetbox.margin_bottom = 10;

// assemble node params

		print("building node param container...\n");
		Gtk.Box parambox = new Gtk.Box(VERTICAL,10);
		parambox.append(headbox);
		parambox.append(filebox);
		parambox.append(presetbox);
		parambox.vexpand = true;
		paramscroll.set_child(parambox);
		paramscrollbox.append(paramscroll);
		paramscrollbox.vexpand = true;
		paramscrollbox.margin_bottom = 10;

// the node list

		print("building node drawingareas...\n");
		Gtk.DrawingArea nodelist = new Gtk.DrawingArea();

// the node graph

		Gtk.DrawingArea nodegraph = new Gtk.DrawingArea();

// swishbox for: node graph, node list

		print("building node stack...\n");
		Gtk.Stack nodestack = new Gtk.Stack();
		nodestack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

		//nodestack.add_titled(nodegraph,"graph","graph");
		//nodestack.add_titled(nodelist,"list","list");
		nodestack.margin_top = 0;
		nodestack.margin_end = 0;
		nodestack.margin_start = 0;
		nodestack.margin_bottom = 0;	

		print("building nodestack event...\n");
		nodestack.notify["visible_child"].connect(() => {
			print("nodestack changed...\n");
		});
		print("building nodeswish...\n");
		Gtk.StackSwitcher nodeswish = new Gtk.StackSwitcher();
		nodeswish.set_stack(nodestack);
		nodeswish.margin_top = 0;
		nodeswish.margin_end = 0;
		nodeswish.margin_start = 0;
		nodeswish.margin_bottom = 0;			

		Gtk.Box nodeswishbox = new Gtk.Box(VERTICAL,0);
		nodeswishbox.append(nodestack);
		nodeswishbox.append(nodeswish);

// node hdiv
		print("building node pane hdiv...\n");
		Gtk.Paned hdiv = new Gtk.Paned(HORIZONTAL);
		hdiv.start_child = nodeswishbox;
		hdiv.end_child = paramscrollbox;
		hdiv.position = 0;
		hdiv.resize_start_child = true;
		hdiv.wide_handle = true;

// the src pane
		print("building src pane...\n");
		Gtk.Box srcscrollbox = new Gtk.Box(VERTICAL,10);
		Gtk.ScrolledWindow srcscroll = new Gtk.ScrolledWindow();
		srcscroll.height_request = 200;
		Gtk.TextTagTable srctextbufftags = new Gtk.TextTagTable();
		GtkSource.Buffer srctextbuff = new GtkSource.Buffer(srctextbufftags);
		srctext = new GtkSource.View.with_buffer(srctextbuff);
		srctextbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme("Adwaita-dark"));
		srctextbuff.set_language(GtkSource.LanguageManager.get_default().get_language("html"));
		srctext.accepts_tab = true;
		srctext.set_monospace(true);

		srctextbuff.set_highlight_syntax(true);	
		srctext.buffer.changed.connect(() => {
			if (doup) {
				doup = false;
				if (srctext.buffer.text != null) {
					int sidx = getselectednode(selectednode);
					allknodes[sidx].src = srctext.buffer.text;
				}
				doup = true;
			}
		});	

		srctext.tab_width = 2;
		srctext.indent_on_tab = true;
		srctext.indent_width = 2;
		srctext.show_line_numbers = true;
		srctext.highlight_current_line = true;
		srctext.vexpand = true;
		srctext.top_margin = 10;
		srctext.left_margin = 10;
		srctext.right_margin = 10;
		srctext.bottom_margin = 10;
		srctext.space_drawer.enable_matrix = true;

		srctext.opacity = 1.0;

		srcscroll.set_child(srctext);
		srcscrollbox.append(srcscroll);
		srcscrollbox.vexpand = true;
		srcscrollbox.margin_top = 0;
		srcscrollbox.margin_end = 0;
		srcscrollbox.margin_start = 0;
		srcscrollbox.margin_bottom = 0;

// the output pane

		print("building res pane...\n");
		Gtk.TextTagTable resbufftags = new Gtk.TextTagTable();
		GtkSource.Buffer resbuff = new GtkSource.Buffer(resbufftags);
		GtkSource.View resoutput = new GtkSource.View.with_buffer(resbuff);
		resbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme("Adwaita-dark"));
		resbuff.set_language(GtkSource.LanguageManager.get_default().get_language("html"));
		resbuff.set_highlight_syntax(true);		

		resoutput.buffer.set_text("parser output goes here");
		resoutput.accepts_tab = true;
		resoutput.set_monospace(true);
		resoutput.tab_width = 2;
		resoutput.indent_on_tab = true;
		resoutput.indent_width = 4;
		resoutput.show_line_numbers = true;
		resoutput.highlight_current_line = true;
		resoutput.vexpand = true;
		resoutput.top_margin = 10;
		resoutput.left_margin = 10;
		resoutput.right_margin = 10;
		resoutput.bottom_margin = 10;
		resoutput.space_drawer.enable_matrix = true;

		resoutput.vexpand = true;
		Gtk.ScrolledWindow resscroll = new Gtk.ScrolledWindow();
		Gtk.Box resscrollbox = new Gtk.Box(VERTICAL,10);
		resscroll.set_child(resoutput);
		resscrollbox.append(resscroll);

// reference pane

		print("building ref pane...\n");
		Gtk.TextTagTable refbufftags = new Gtk.TextTagTable();
		GtkSource.Buffer refbuff = new GtkSource.Buffer(refbufftags);
		GtkSource.View refoutput = new GtkSource.View.with_buffer(refbuff);
		refbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme("Adwaita-dark"));
		refbuff.set_language(GtkSource.LanguageManager.get_default().get_language("html"));
		refbuff.set_highlight_syntax(true);		

		refoutput.buffer.set_text("reference code goes here");
		refoutput.accepts_tab = true;
		refoutput.set_monospace(true);
		refoutput.tab_width = 2;
		refoutput.indent_on_tab = true;
		refoutput.indent_width = 4;
		refoutput.show_line_numbers = true;
		refoutput.highlight_current_line = true;
		refoutput.vexpand = true;
		refoutput.top_margin = 10;
		refoutput.left_margin = 10;
		refoutput.right_margin = 10;
		refoutput.bottom_margin = 10;
		refoutput.space_drawer.enable_matrix = true;

		Gtk.DropDown reftypelist = new Gtk.DropDown(null,null);
		reftypelist.set_model(new Gtk.StringList({"reference", "presets", "source", "output"}));
		reftypelist.set_selected(0);

		Gtk.Entry reffileentry = new Gtk.Entry();
		reffileentry.hexpand = true;
		Gtk.CssProvider rfsp = new Gtk.CssProvider();
		string rfss = ".xx { background: #00000010; }";
		rfsp.load_from_data(rfss.data);
		reffileentry.get_style_context().add_provider(rfsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		reffileentry.get_style_context().add_class("xx");	
		reffileentry.changed.connect(() => {
			if (doup) {
				doup = false;
				File lodfile = getfiledir(reffileentry.text);
				print("lodfile is %s\n",lodfile.get_path());
				if (lodfile.query_exists() == true) {
					rfss = ".xx { background: #00FF0020; }";
					rfsp.load_from_data(rfss.data);
				} else {
					rfss = ".xx { background: #FF000020; }";
					rfsp.load_from_data(rfss.data);	
				}
				doup = true;
			}
		});
		reffileentry.editing_done.connect(() => {
			if (doup) {
				doup = false;
				bool allgood = false;
				if (reffileentry.text != null) {
					if (reffileentry.text.strip() != "") {
						File og = getfiledir(reffileentry.text.strip());
						print("og is %s\n",og.get_path());
						if (og.query_exists() == true) {
							bool dobuff = false;
							string rets = "";
							try {
								uint8[] c; string e;
								og.load_contents (null, out c, out e);
								rets = ((string) c);
								rfss = ".xx { background: #00FF0020; }";
								rfsp.load_from_data(rfss.data);
								dobuff = true; allgood = true;
							} catch (Error e) {
								print ("failed to read %s: %s\n", og.get_path(), e.message);
								rfss = ".xx { background: #FF000020; }";
								rfsp.load_from_data(rfss.data);	
							}
							if (dobuff) {
								string fex = getfileext(og.get_path());
								if (fex != null) {
									if (fex.strip() != "") { 
										string sch = "Adwaita-dark";
										string lng = "text";
										if (fex == "py") { lng = "python"; }
										if (fex == "r3" || fex == "r")  { lng = "rebol"; sch = "Adwaita-gifded"; }
										if (fex == "sh") { lng = "sh"; }
										if (fex == "html" || fex == "htm") { lng = "html"; }
										if (fex == "org") { lng = "orgmode"; sch = "Adwaita-orgmode"; }
										if (fex == "txt") { lng = "text"; }
										refbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme(sch));
										refbuff.set_language(GtkSource.LanguageManager.get_default().get_language(lng));
										refoutput.buffer.text = rets;
									} else { allgood = false; print("file extension is empty: %s\n", og.get_path()); }
								} else { allgood = false; print("file extension is null: %s\n", og.get_path()); }
							}
						}
					}
				} 
				if (allgood == false) { rfss = ".xx { background: #FF000020; }"; rfsp.load_from_data(rfss.data); }
				doup = true;
			}
		});
		print("building ref popmenu...\n");
		Gtk.MenuButton reffilebutton = new Gtk.MenuButton();
		reffilebutton.icon_name = "document-open-symbolic";
		Gtk.Popover reffilepop = new Gtk.Popover();
		reffilepop.has_arrow = false;
		Gtk.Box reffilepopbox = new Gtk.Box(VERTICAL,2);
		Gtk.ScrolledWindow refpopscroll = new Gtk.ScrolledWindow();
		reffilepopbox.margin_top = 5;
		reffilepopbox.margin_end = 5;
		reffilepopbox.margin_start = 5;
		reffilepopbox.margin_bottom = 5;
		refpopscroll.set_child(reffilepopbox);
		reffilepop.width_request = 300;
		wwx = 0; wwy = 0;
		this.get_default_size(out wwx,out wwy);
		reffilepop.height_request = (wwy - 200);
		reffilepop.set_child(refpopscroll);
		reffilebutton.popover = reffilepop;
		reffilepop.set_position(TOP);
		Gtk.GestureClick reffileclick = new Gtk.GestureClick();
		reffilebutton.add_controller(reffileclick);
		reffileclick.pressed.connect(() => {
			if (doup) {
				doup = false;
				while (reffilepopbox.get_first_child() != null) {
					reffilepopbox.remove(reffilepopbox.get_first_child());
				}
				string scandir = "reference";
				if (reftypelist.selected == 1) { scandir = "presets"; }
				if (reftypelist.selected == 2) { scandir = "source"; }
				if (reftypelist.selected == 3) { scandir = "output"; }
				string pth = GLib.Environment.get_current_dir();
				File srcpath = File.new_for_path (pth.concat("/",scandir,"/"));
				if (srcpath.query_exists() == false) { srcpath.make_directory_with_parents(); }
				bool allgood = true;
				GLib.Dir dcr = null;
				try { dcr = Dir.open (srcpath.get_path(), 0); } catch (Error e) { print("%s\n",e.message); allgood = false; }
				if (allgood) {
					Gtk.CssProvider mubcsp = new Gtk.CssProvider();
					string mubcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sblight,sbselect);
					mubcsp.load_from_data(mubcss.data);
					string? name = null;
					while ((name = dcr.read_name ()) != null) {
						string[] exts = name.split(".");
						if (exts.length == 2) {
							if (exts[1].strip() != "" ) {
								Gtk.Button muh = new Gtk.Button.with_label (name);
								muh.get_style_context().add_provider(mubcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
								muh.get_style_context().add_class("xx");
								reffilepopbox.append(muh);
								muh.clicked.connect ((buh) => {
									string nm = buh.label;
									string fff = "./".concat(scandir,"/", nm);
									File og = File.new_for_path(fff);
									reffileentry.text = fff;
									bool dobuff = false;
									string rets = "";
									try {
										uint8[] c; string e;
										og.load_contents (null, out c, out e);
										rets = ((string) c);
										rfss = ".xx { background: #00FF0020; }";
										rfsp.load_from_data(rfss.data);
										dobuff = true;
									} catch (Error e) {
										print ("failed to read %s: %s\n", og.get_path(), e.message);
										rfss = ".xx { background: #FF000020; }";
										rfsp.load_from_data(rfss.data);	
									}
									if (dobuff) {
										string fex = getfileext(og.get_path());
										if (fex != null) {
											if (fex.strip() != "") { 
												string sch = "Adwaita-dark";
												string lng = "text";
												if (fex == "py") { lng = "python"; }
												if (fex == "r3" || fex == "r")  { lng = "rebol"; sch = "Adwaita-gifded"; }
												if (fex == "sh") { lng = "sh"; }
												if (fex == "html" || fex == "htm") { lng = "html"; }
												if (fex == "org") { lng = "orgmode"; sch = "Adwaita-orgmode"; }
												if (fex == "txt") { lng = "text"; }
												refbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme(sch));
												refbuff.set_language(GtkSource.LanguageManager.get_default().get_language(lng));
												refoutput.buffer.text = rets;
											}
										}
									}
									reffilepop.popdown();
								});
							}
						}
					}
				}
				doup = true;
			}
		});
		print("building ref control box...\n");
		Gtk.Box refcontrolbox = new Gtk.Box(HORIZONTAL,0);
	
		refcontrolbox.append(reftypelist);
		refcontrolbox.append(reffilebutton);
		refcontrolbox.append(reffileentry);
		refcontrolbox.vexpand = false;
		refcontrolbox.hexpand = true;
		refcontrolbox.margin_top = 0;
		refcontrolbox.margin_end = 0;
		refcontrolbox.margin_start = 0;
		refcontrolbox.margin_bottom = 0;		

		Gtk.ScrolledWindow refscroll = new Gtk.ScrolledWindow();
		Gtk.Box refscrollbox = new Gtk.Box(VERTICAL,10);
		refscroll.set_child(refoutput);
		refscrollbox.append(refscroll);

		Gtk.Box refpane = new Gtk.Box(VERTICAL,0);
		refpane.append(refscrollbox);
		refpane.append(refcontrolbox);

// swishbox for: output html, output render, data view

		print("building view stack...\n");
		Gtk.Stack viewstack = new Gtk.Stack();
		viewstack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

		viewstack.add_titled(resscrollbox,"result","result");
		viewstack.add_titled(refpane,"ref","ref");
		viewstack.add_titled(srcscrollbox,"source","source");
		viewstack.add_titled(nodegraph,"graph","graph");
		viewstack.add_titled(nodelist,"list","list");
		viewstack.margin_top = 0;
		viewstack.margin_end = 0;
		viewstack.margin_start = 0;
		viewstack.margin_bottom = 0;	

		viewstack.notify["visible_child"].connect(() => {
			print("viewstack changed\n");
		});

		Gtk.StackSwitcher viewswish = new Gtk.StackSwitcher();
		viewswish.set_stack(viewstack);
		viewswish.margin_top = 0;
		viewswish.margin_end = 0;
		viewswish.margin_start = 0;
		viewswish.margin_bottom = 0;			

		Gtk.Box viewswishbox = new Gtk.Box(VERTICAL,0);
		viewswishbox.append(viewstack);
		viewswishbox.append(viewswish);

// toplevel ui

		Gtk.Paned vdiv = new Gtk.Paned(VERTICAL);
		vdiv.start_child = viewswishbox;
		vdiv.end_child = hdiv;
		vdiv.wide_handle = true;
		vdiv.set_shrink_end_child(false);

		var fch = (Gtk.Widget) vdiv.get_start_child();
		var sep = (Gtk.Widget) fch.get_next_sibling();
		fch = (Gtk.Widget) hdiv.get_start_child();
		var hsep = (Gtk.Widget) fch.get_next_sibling();

// add to window

		this.set_child(vdiv);
		vdiv.position = 600;

// style

	// string sbbackground 	= "#112633FF";	// sb blue
	// string sbselect 		= "#327299FF";	// bright selection
	// string sblines 		= "#08131AFF";	// dark lines
	// string sblight 		= "#19394DFF";	// +5 background
	// string sbshade 		= "#0C1D26FF";	// -5 background
	// string sbentry 		= "#0E232EFF";	// -2 background


// paned

		Gtk.CssProvider sepcsp = new Gtk.CssProvider();
		string sepcss = ".wide { min-width: 20px; min-height: 20px; border-width: 4px; border-color: %s; border-style: solid; background: %s;}".printf(sbshade, sbshade);
		sepcsp.load_from_data(sepcss.data);
		sep.get_style_context().add_provider(sepcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		sep.get_style_context().add_class("wide");

		Gtk.CssProvider hsepcsp = new Gtk.CssProvider();
		string hsepcss = ".wide { min-width: 0px; min-height: 20px; border-width: 0px; border-color: %s; border-style: solid; background: %s;}".printf(sbshade, sbshade);
		hsepcsp.load_from_data(hsepcss.data);
		hsep.get_style_context().add_provider(hsepcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);		
		hsep.get_style_context().add_class("wide");

// window

		Gtk.CssProvider wincsp = new Gtk.CssProvider();
		string wincss = ".xx { border-radius: 0; border-color: %s; background: %s; }".printf(sblines,sbbackground);
		wincsp.load_from_data(wincss.data);
		this.get_style_context().add_provider(wincsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		this.get_style_context().add_class("xx");

// entry fields

		Gtk.CssProvider entcsp = new Gtk.CssProvider();
		string entcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sbshade,sbselect);
		entcsp.load_from_data(entcss.data);
		nameentry.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		nameentry.get_style_context().add_class("xx");
		fileentry.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		fileentry.get_style_context().add_class("xx");
		reffileentry.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		reffileentry.get_style_context().add_class("xx");
		presetentry.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		presetentry.get_style_context().add_class("xx");

// header bar

		Gtk.CssProvider hedcsp = new Gtk.CssProvider();
		string hedcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sbshade,sbselect);
		hedcsp.load_from_data(hedcss.data);
		tbar.get_style_context().add_provider(hedcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		tbar.get_style_context().add_class("xx");

// buttons

		Gtk.CssProvider butcsp = new Gtk.CssProvider();
		string butcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sblight,sbselect);
		butcsp.load_from_data(butcss.data);
		dsav.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		dsav.get_style_context().add_class("xx");
		dpub.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		dpub.get_style_context().add_class("xx");
		presetsave.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		presetsave.get_style_context().add_class("xx");

// menu buttons

		Gtk.CssProvider mnucsp = new Gtk.CssProvider();
		string mnucss = ".xx { border-radius: 0; border-color: %s; background-color: %s; background: %s; color: %s; }".printf(sblines,sblight,sblight,sbselect);
		mnucsp.load_from_data(mnucss.data);
		filebutton.get_first_child().get_style_context().add_provider(mnucsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		filebutton.get_first_child().get_style_context().add_class("xx");
		presetbutton.get_first_child().get_style_context().add_provider(mnucsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		presetbutton.get_first_child().get_style_context().add_class("xx");
		reffilebutton.get_first_child().get_style_context().add_provider(mnucsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		reffilebutton.get_first_child().get_style_context().add_class("xx");

// popmenu

		Gtk.CssProvider popcsp = new Gtk.CssProvider();
		string popcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sbbackground,sbselect);
		popcsp.load_from_data(popcss.data);
		presetpop.get_first_child().get_style_context().add_provider(popcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		presetpop.get_first_child().get_style_context().add_class("xx");
		reffilepop.get_first_child().get_style_context().add_provider(popcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		reffilepop.get_first_child().get_style_context().add_class("xx");
		filepop.get_first_child().get_style_context().add_provider(popcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		filepop.get_first_child().get_style_context().add_class("xx");

// dropmenu -- should replace this with popmenu

		Gtk.CssProvider drpcsp = new Gtk.CssProvider();
		string drpcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblines,sbbackground,sbselect);
		drpcsp.load_from_data(drpcss.data);

		Gtk.CssProvider hovcsp = new Gtk.CssProvider();
		string hovcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }\n.xx:hover { background: %s; color: %s; }".printf(sblines,sbbackground,sbselect,sbselect,sblines);
		hovcsp.load_from_data(hovcss.data);

		Gtk.CssProvider transcsp = new Gtk.CssProvider();
		string transcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: inherit; }".printf(sblines,"#00000000");
		transcsp.load_from_data(transcss.data);

// let's ride the crazytrain to loosertown...

		oplist.get_first_child().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		oplist.get_first_child().get_style_context().add_class("xx");

		// oplist.Box
		oplist.get_last_child().get_first_child().get_first_child().get_style_context().add_provider(transcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		oplist.get_last_child().get_first_child().get_first_child().get_style_context().add_class("xx");

		// oplist.Box.Box
		oplist.get_last_child().get_first_child().get_first_child().get_first_child().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		oplist.get_last_child().get_first_child().get_first_child().get_first_child().get_style_context().add_class("xx");

		// oplist.Box.Box.ScrolledWindow
 		oplist.get_last_child().get_first_child().get_first_child().get_first_child().get_next_sibling().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		 oplist.get_last_child().get_first_child().get_first_child().get_first_child().get_next_sibling().get_style_context().add_class("xx");

		// oplist.Box.Box.ScrolledWindow.ListBox
		oplist.get_last_child().get_first_child().get_first_child().get_last_child().get_first_child().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		oplist.get_last_child().get_first_child().get_first_child().get_last_child().get_first_child().get_style_context().add_class("xx");

		// oplist.Box.Box.ScrolledWindow.ListBox.Row[]
		Gtk.Widget ch = oplist.get_last_child().get_first_child().get_first_child().get_last_child().get_first_child().get_first_child();
		while(ch != null) {
			ch.get_style_context().add_provider(hovcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			ch.get_style_context().add_class("xx");
			// Row.Box
			ch.get_first_child().get_style_context().add_provider(transcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			ch.get_first_child().get_style_context().add_class("xx");
			// Row.Box.Label
			ch.get_first_child().get_first_child().get_style_context().add_provider(transcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			ch.get_first_child().get_first_child().get_style_context().add_class("xx");
			ch = ch.get_next_sibling();
		}

		reftypelist.get_first_child().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		reftypelist.get_first_child().get_style_context().add_class("xx");

		// reftypelist.Box
		reftypelist.get_last_child().get_first_child().get_first_child().get_style_context().add_provider(transcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		reftypelist.get_last_child().get_first_child().get_first_child().get_style_context().add_class("xx");

		// reftypelist.Box.Box
		reftypelist.get_last_child().get_first_child().get_first_child().get_first_child().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		reftypelist.get_last_child().get_first_child().get_first_child().get_first_child().get_style_context().add_class("xx");

		// reftypelist.Box.Box.ScrolledWindow
 		reftypelist.get_last_child().get_first_child().get_first_child().get_first_child().get_next_sibling().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		 reftypelist.get_last_child().get_first_child().get_first_child().get_first_child().get_next_sibling().get_style_context().add_class("xx");

		// reftypelist.Box.Box.ScrolledWindow.ListBox
		reftypelist.get_last_child().get_first_child().get_first_child().get_last_child().get_first_child().get_style_context().add_provider(drpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		reftypelist.get_last_child().get_first_child().get_first_child().get_last_child().get_first_child().get_style_context().add_class("xx");

		// reftypelist.Box.Box.ScrolledWindow.ListBox.Row[]
		ch = reftypelist.get_last_child().get_first_child().get_first_child().get_last_child().get_first_child().get_first_child();
		while(ch != null) {
			ch.get_style_context().add_provider(hovcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			ch.get_style_context().add_class("xx");
			// Row.Box
			ch.get_first_child().get_style_context().add_provider(transcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			ch.get_first_child().get_style_context().add_class("xx");
			// Row.Box.Label
			ch.get_first_child().get_first_child().get_style_context().add_provider(transcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			ch.get_first_child().get_first_child().get_style_context().add_class("xx");
			ch = ch.get_next_sibling();
		}

// toggle buttons

		Gtk.CssProvider swishcsp = new Gtk.CssProvider();
		string swishcss = ".hh { color: %s; border-radius: 0; background: %s; min-width: 30px; }\n.hh:checked { color: %s; background: %s; min-width: 30px; }".printf(sbselect, sblight, sbshade, sbselect);
		swishcsp.load_from_data(swishcss.data);
		foldbutton.get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		foldbutton.get_style_context().add_class("hh");
		freezebutton.get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		freezebutton.get_style_context().add_class("hh");
		enabledbutton.get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		enabledbutton.get_style_context().add_class("hh");

		viewswish.get_first_child().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		viewswish.get_first_child().get_style_context().add_class("hh");

		viewswish.get_first_child().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		viewswish.get_first_child().get_next_sibling().get_style_context().add_class("hh");

		viewswish.get_first_child().get_next_sibling().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		viewswish.get_first_child().get_next_sibling().get_next_sibling().get_style_context().add_class("hh");

		viewswish.get_first_child().get_next_sibling().get_next_sibling().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		viewswish.get_first_child().get_next_sibling().get_next_sibling().get_next_sibling().get_style_context().add_class("hh");

		viewswish.get_last_child().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		viewswish.get_last_child().get_style_context().add_class("hh");


// initialize

		doup = false;
		knode ee = knode();
		ee.nom = "load file";
		ee.typ = "Load";
		ee.frz = false;
		ee.hoi = true;
		ee.pox = 10.0;
		ee.poy = 10.0;
		int64 mm = GLib.get_real_time () / 1000;
		mm = mm + ee.nom.hash();
		ee.idx = mm.to_string();
		allknodes += ee;

		knode gg = knode();
		gg.nom = "script parser";
		gg.typ = "Script";
		gg.frz = false;
		gg.hoi = true;
		gg.cex = "rebol";
		gg.src = "REBOL []\n;script goes here...";
		gg.pox = 30.0;
		gg.poy = 50.0;
		mm = GLib.get_real_time () / 1000;
		mm = mm + gg.nom.hash();
		gg.idx = mm.to_string();
		allknodes += gg;

		selectednode = ee.idx;
		nodegraph.queue_draw();
		doup = true;

// events

		this.notify.connect(() => {
			int wx, wy = 0;
			this.get_default_size(out wx,out wy);
			if (wx != winx || wy != winy) {
				winx = wx; winy = wy;
				if ((wx > 720) && (wx > wy)) {
					if (amdesktop == false) {
						if (vdiv.get_orientation() == VERTICAL) {
							print("window size is %dx%d\n",wx,wy);
							amdesktop = true; amphone = false;
							vdiv.set_orientation(HORIZONTAL);
							hdiv.set_orientation(VERTICAL);
							vdiv.position = (wx - 400);
							hdiv.position = 300;
							hsepcss = ".wide { min-width: 20px; min-height: 20px; border-width: 4px; border-color: %s; border-style: solid; background: %s;}".printf(sbshade, sbshade);
							hsepcsp.load_from_data(hsepcss.data);
							viewstack.remove(nodegraph);
							viewstack.remove(nodelist);
							nodestack.add_titled(nodelist,"list","list");
							nodestack.add_titled(nodegraph,"graph","graph");
							nodeswish.set_stack(nodestack);
							nodestack.set_visible_child(nodegraph);
							viewswish.get_first_child().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_first_child().get_style_context().add_class("hh");

							viewswish.get_first_child().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_first_child().get_next_sibling().get_style_context().add_class("hh");

							viewswish.get_first_child().get_next_sibling().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_first_child().get_next_sibling().get_next_sibling().get_style_context().add_class("hh");

							nodeswish.get_first_child().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							nodeswish.get_first_child().get_style_context().add_class("hh");

							nodeswish.get_last_child().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							nodeswish.get_last_child().get_style_context().add_class("hh");
						}
					}
				}
				if ((wx < 720) && (wx < wy)) {
					if (amphone == false) {
						if (vdiv.get_orientation() == HORIZONTAL) {
							amphone = true; amdesktop = false;
							vdiv.set_orientation(VERTICAL);
							hdiv.set_orientation(HORIZONTAL);
							vdiv.position = (wy - 65);
							hdiv.position = 0;
							hsepcss = ".wide { min-width: 0px; min-height: 20px; border-width: 0px; border-color: %s; border-style: solid; background: %s;}".printf(sbshade, sbshade);
							hsepcsp.load_from_data(hsepcss.data);
							nodestack.remove(nodelist);
							nodestack.remove(nodegraph);
							viewstack.add_titled(nodelist,"list","list");
							viewstack.add_titled(nodegraph,"graph","graph");
							viewswish.set_stack(viewstack);
							viewstack.set_visible_child(nodegraph);
							viewswish.get_first_child().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_first_child().get_style_context().add_class("hh");

							viewswish.get_first_child().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_first_child().get_next_sibling().get_style_context().add_class("hh");

							viewswish.get_first_child().get_next_sibling().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_first_child().get_next_sibling().get_next_sibling().get_style_context().add_class("hh");

							viewswish.get_first_child().get_next_sibling().get_next_sibling().get_next_sibling().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_first_child().get_next_sibling().get_next_sibling().get_next_sibling().get_style_context().add_class("hh");

							viewswish.get_last_child().get_style_context().add_provider(swishcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
							viewswish.get_last_child().get_style_context().add_class("hh");
						}
					}
				}
			}		
		});

// graph interaction

		Gtk.GestureDrag ng_touchpan = new Gtk.GestureDrag();
		Gtk.EventControllerScroll ng_wheeler = new Gtk.EventControllerScroll(VERTICAL);
		Gtk.EventControllerMotion ng_hover = new Gtk.EventControllerMotion();
		ng_touchpan.set_button(0);
		nodegraph.add_controller(ng_touchpan);
		nodegraph.add_controller(ng_wheeler);
		nodegraph.add_controller(ng_hover);

		ng_touchpan.drag_begin.connect ((event, x, y) => {
			if (drwm == 0) {
				ipik = (event.get_current_button() == 1);
				izom = (event.get_current_button() == 3);
				ipan = (event.get_current_button() == 2);
				ng_mdwn = {x, y};
				if (ipik) {
					ng_olmd = {ng_mdwn[0], ng_mdwn[1]};
					ng_trgx = ng_mdwn[0];
					ng_trgy = ng_mdwn[1];
					nodegraph.queue_draw();
				}
			}
		});
		ng_touchpan.drag_update.connect((event, x, y) => {
			if (drwm == 0) {
				//ipik = false;
				if (izom == false && ipan == false && ipik == false) { ng_mdwn = {x, y}; }
				ng_moom = {x, y};
				if (izom || ipan) { nodegraph.queue_draw(); }
				//if (event.get_current_button() == 1 && ng_node >= 0) { igrb = true; nodegraph.queue_draw(); }
			}
		});
		ng_hover.motion.connect ((event, x, y) => {
			if (drwm == 0) {
				if (izom == false && ipan == false && ipik == false) { ng_mdwn = {x, y}; }
			}
		});
		ng_touchpan.drag_end.connect(() => {
			ipan = false;
			izom = false;
			iscr = false;
			igrb = false;
			if (drwm == 0) { 
				if (ipik) { nodegraph.queue_draw(); }
				ng_olsz = {ng_sizx, ng_sizy};
				ng_olof = {ng_posx, ng_posy};
				ng_olmd = {ng_trgx, ng_trgy};
				ng_olbh = ng_barh;
				//print("current node list index is: %d\n", ng_node);
				//if (igrb) { allknodes[ng_node].pox = ng_nox; allknodes[ng_node].poy = ng_noy; igrb = false; }
			}
			if (dosel) { selectnode(selectednode); dosel = false; }
			//ng_node = -1;
		});
		ng_wheeler.scroll.connect ((x,y) => {
			iscr = true;
			if (drwm == 0) {
				ng_moom = {(-y * 50.0), (-y * 50.0)};
				nodegraph.queue_draw();
			}
		});

///////////////////////////////
//                           //
//    node graph rendering   //
//                           //
///////////////////////////////

		nodegraph.set_draw_func((da, ctx, daw, dah) => {
			if (allknodes.length > 0) {
				var presel = selectednode;
				var csx = nodegraph.get_allocated_width();
				var csy = nodegraph.get_allocated_height();
				var px = 0.0;
				var py = 0.0;

// graph coords

				ng_sizx = ng_olsz[0];
				ng_sizy = ng_olsz[1];

				if (izom || iscr) {
					ng_sizx = (ng_olsz[0] + ng_moom[0]);
					ng_sizy = (ng_olsz[1] + ng_moom[1]);
				}

				ng_posy = ng_olof[1];
				ng_posx = ng_olof[0];
				
				if (izom || iscr) {
					ng_barh = ng_olbh * (ng_sizy / ng_olsz[1]);
					ng_posx = ng_olof[0] + ( (ng_mdwn[0] - ng_olof[0]) - ( (ng_mdwn[0] - ng_olof[0]) * (ng_sizx / ng_olsz[0]) ) ) ;
					ng_posy = ng_olof[1] + ( (ng_mdwn[1] - ng_olof[1]) - ( (ng_mdwn[1] - ng_olof[1]) * (ng_sizy / ng_olsz[1]) ) ) ;
					ng_trgx = ng_olmd[0] + ( (ng_mdwn[0] - ng_olmd[0]) - ( (ng_mdwn[0] - ng_olmd[0]) * (ng_sizx / ng_olsz[0]) ) ) ;
					ng_trgy = ng_olmd[1] + ( (ng_mdwn[1] - ng_olmd[1]) - ( (ng_mdwn[1] - ng_olmd[1]) * (ng_sizy / ng_olsz[1]) ) ) ;
				}

				if(ipan) {
					ng_posx = ng_olof[0] + ng_moom[0];
					ng_posy = ng_olof[1] + ng_moom[1];
					ng_trgx = ng_olmd[0] + ng_moom[0];
					ng_trgy = ng_olmd[1] + ng_moom[1];
				}
	
				if (ipik) {
					ng_trgx = ng_mdwn[0];
					ng_trgy = ng_mdwn[1];
				}

				print("nodegraph.set_draw_func:\tsizx : %f\n", ng_sizx); 
				print("nodegraph.set_draw_func:\tsizy : %f\n", ng_sizy); 
				print("nodegraph.set_draw_func:\tposx : %f\n", ng_posx); 
				print("nodegraph.set_draw_func:\tposy : %f\n", ng_posy);
				print("nodegraph.set_draw_func:\ttrgx : %f\n", ng_trgx); 
				print("nodegraph.set_draw_func:\ttrgy : %f\n", ng_trgy);

// bar height

				ctx.select_font_face("Monospace",Cairo.FontSlant.NORMAL,Cairo.FontWeight.BOLD);
				ctx.set_font_size(double.min(ng_barh * 0.8, 30.0)); 
				Cairo.TextExtents extents;
				ctx.text_extents (allknodes[0].nom, out extents);
				var xx = extents.width + 40.0;

// clamp pos y

				//ng_posy = double.min(double.max(ng_posy, (0 - ((ng_barh * allknodes.length)-dah))), 0.0);
				//ng_posx = double.min(double.max(ng_posx, (daw - xx)), 0.0);

// paint bg

				var bc = Gdk.RGBA();
				bc.parse(sbshade);
				ctx.set_source_rgba(bc.red,bc.green,bc.blue,1);
				ctx.paint();

// rows

				var gxx = 0.0;
				var gyy = 0.0;
				var ptx = 0.0;
				var pty = 0.0;
				var ptw = 0.0;
				var pth = 0.0;
				var rsx = (ng_sizx / ng_olsz[0]);		// relative scale x
				var rsy = (ng_sizy / ng_olsz[1]);		// relative scale y
				var asx = (ng_sizx / ng_ogsz[0]);		// absolute scale x
				var asy = (ng_sizy / ng_ogsz[1]);		// absolute scale y
					
				for (int i = 0; i < allknodes.length; i++) {
					px = (allknodes[i].pox * asx) + ng_posx;
					py = (allknodes[i].poy * asy) + ng_posy;
					string xinf = allknodes[i].nom;
					bc.parse(sblight);
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
					ctx.rectangle(px, py, (50.0 * asx), (30.0 * asy));
					ctx.fill();
				}


// reset mouseown if not doing anythting with it

				if (izom == false && ipan == false && iscr == false) {
					ng_mdwn[0] = 0;
					ng_mdwn[1] = 0;
					ipik = false;
				}

// wheel has no end event, so have to terminate it here

				if (iscr) {
					iscr = false;
					ng_olsz = {ng_sizx, ng_sizy};
					ng_olof = {ng_posx, ng_posy};
					ng_olmd = {ng_trgx, ng_trgy};
				}
			}
		});
	}
}


int main (string[] args) {
	var app = new knoms();
	app.activate.connect (() => {
		var win = new hnwin(app);
		win.present ();
	});
	return app.run (args);
}

