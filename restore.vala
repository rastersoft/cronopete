/*
 Copyright 2011 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Cronopete

 Nanockup is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 Nanockup is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using GLib;
using Gee;
using Gtk;
using Clutter;

class restore_iface : GLib.Object {

	private Stage stage;
	private Rectangle[] rectangles;
	private Window mywin;

	const string[] colors = {
		"blanched almond",
		"OldLace",
		"MistyRose",
		"White",
		"LavenderBlush",
		"CornflowerBlue",
		"chartreuse",
		"chocolate",
		"light coral",
		"medium violet red",
		"LemonChiffon2",
		"RosyBrown3"
	};

	public restore_iface () {
	
		mywin = new Window();
		var stwidget = new GtkClutter.Embed();
		mywin.fullscreen();
		mywin.add(stwidget);
		mywin.show_all();
		
		stage = (Stage) stwidget.get_stage();

		rectangles = new Rectangle[colors.length];
		stage.hide.connect (Clutter.main_quit);

		create_rectangles ();

		stage.color = Color () { alpha = 255 };
		stage.show_all ();
	}

	private void create_rectangles () {
		for (int i = 0; i < colors.length; i++) {
			var r = new Rectangle ();

			r.width = r.height = stage.height / colors.length;
			r.color = Color.from_string (colors[i]);
			r.anchor_gravity = Gravity.CENTER;
			r.y = i * r.height + r.height / 2;

			stage.add_actor (r);

			rectangles[i] = r;
		}
	}

	public void start () {
		var animations = new Animation[rectangles.length];
		for (int i = 0; i < rectangles.length; i++) {
			animations[i] = rectangles[i].animate (
									  AnimationMode.LINEAR, 5000,
									  x: stage.width / 2,
									  rotation_angle_z: 500.0);
		}
		animations[animations.length - 1].completed.connect (() => {
			var text = new Text.full ("Bitstream Vera Sans 40","Congratulations!",Color.from_string ("white"));

			text.anchor_gravity = Gravity.CENTER;
			text.x = stage.width / 2;
			text.y = -text.height;	// Off-stage
			stage.add_actor (text);
			text.animate (AnimationMode.EASE_OUT_BOUNCE, 3000,
						  y: stage.height / 2);

			for (int i = 0; i < rectangles.length; i++) {
				rectangles[i].animate (
						AnimationMode.EASE_OUT_BOUNCE, 3000,
						x: Random.next_double () * stage.width,
						y: Random.next_double () * stage.height / 2
												 + stage.height / 2,
						rotation_angle_z: rectangles[i].rotation_angle_z,
						opacity: 0);
			}
		});
	}
}