
/******************************************************************************
 * MODULE     : qt_chooser_widget.cpp
 * DESCRIPTION: File chooser widget, native and otherwise
 * COPYRIGHT  : (C) 2008  Massimiliano Gubinelli
 *******************************************************************************
 * This software falls under the GNU general public license version 3 or later.
 * It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
 * in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
 ******************************************************************************/

#include "qt_chooser_widget.hpp"
#include "qt_utilities.hpp"
#include "widget.hpp"
#include "message.hpp"
#include "analyze.hpp"
#include "converter.hpp"
#include "scheme.hpp"
#include "dictionary.hpp"
#include "editor.hpp"
#include "new_view.hpp"      // get_current_editor()
#include "QTMFileDialog.hpp"

#include <QString>
#include <QStringList>
#include <QFileDialog>
#include <QByteArray>

/*!
  \param _cmd  Scheme closure to execute after the dialog is closed.
  \param _type What kind of dialog to show. Can be one of "image", "directory",
               or any of the supported file formats: "texmacs", "tmml",
               "postscript", etc. See perform_dialog()
 */
qt_chooser_widget_rep::qt_chooser_widget_rep (command _cmd, string _type, bool _save)
 : qt_widget_rep (file_chooser), cmd (_cmd), save (_save),
   position (coord2 (0, 0)), size (coord2 (100, 100)), file ("")
{
  if (DEBUG_QT_WIDGETS)
    debug_widgets << "qt_chooser_widget_rep::qt_chooser_widget_rep type=\""
                  << type << "\" save=\"" << save << "\"" << LF;
  if (! set_type (_type))
    set_type ("generic");
}

void
qt_chooser_widget_rep::send (slot s, blackbox val) {
  switch (s) {
    case SLOT_VISIBILITY:
    {   
      check_type<bool> (val, s);
      bool flag = open_box<bool> (val);
      (void) flag;
      NOT_IMPLEMENTED("qt_chooser_widget::SLOT_VISIBILITY");
    }
      break;
    case SLOT_SIZE:
      check_type<coord2>(val, s);
      size = open_box<coord2> (val);
      break;
    case SLOT_POSITION:
      check_type<coord2>(val, s);
      position = open_box<coord2> (val);
      break;
    case SLOT_KEYBOARD_FOCUS:
      check_type<bool>(val, s);
      perform_dialog ();
      break;              
    case SLOT_STRING_INPUT:
      check_type<string>(val, s);
      if (DEBUG_QT_WIDGETS)
        debug_widgets << "\tString input: " << open_box<string> (val) << LF;
      NOT_IMPLEMENTED("qt_chooser_widget::SLOT_STRING_INPUT");
      break;
    case SLOT_INPUT_TYPE:
      check_type<string>(val, s);
      set_type (open_box<string> (val));
      break;
    case SLOT_FILE:
        //send_string (THIS, "file", val);
      check_type<string>(val, s);
      if (DEBUG_QT_WIDGETS)
        debug_widgets << "\tFile: " << open_box<string> (val) << LF;
      file = open_box<string> (val);
      break;
    case SLOT_DIRECTORY:
      check_type<string>(val, s);
      directory = open_box<string> (val);
      directory = as_string (url_pwd () * url_system (directory));
      break;
      
    default:
      qt_widget_rep::send (s, val);
  }
  if (DEBUG_QT_WIDGETS)
    debug_widgets << "qt_chooser_widget_rep: sent " << slot_name (s) 
                  << "\t\tto widget\t"      << type_as_string() << LF;
}

blackbox
qt_chooser_widget_rep::query (slot s, int type_id) {
  if (DEBUG_QT_WIDGETS)
    debug_widgets << "qt_chooser_widget_rep::query " << slot_name(s) << LF;
  switch (s) {
    case SLOT_POSITION:
    {
      check_type_id<coord2> (type_id, s);
      return close_box<coord2> (position);
    }
    case SLOT_SIZE:
    {
      check_type_id<coord2> (type_id, s);
      return close_box<coord2> (size);
    }
    case SLOT_STRING_INPUT:
    {
      check_type_id<string> (type_id, s);
      if (DEBUG_QT_WIDGETS) debug_widgets << "\tString: " << file << LF;
      return close_box<string> (file);
    }
    default:
      return qt_widget_rep::query (s, type_id);
  }
}

widget
qt_chooser_widget_rep::read (slot s, blackbox index) {
  if (DEBUG_QT_WIDGETS)
    debug_widgets << "qt_chooser_widget_rep::read " << slot_name(s) << LF;
  switch (s) {
    case SLOT_WINDOW:
      check_type_void (index, s);
      return this;
    case SLOT_FORM_FIELD:
      check_type<int> (index, s);
      return this;
    case SLOT_FILE:
      check_type_void (index, s);
      return this;
    case SLOT_DIRECTORY:
      check_type_void (index, s);
      return this;
    default:
      return qt_widget_rep::read(s,index);
  }
}

/*!
 @note: name is a unique identifier for the window, but for this widget we
 identify it with the window title. This is not always the case.
 */
widget
qt_chooser_widget_rep::plain_window_widget (string s, command q)
{
  win_title = s;
  quit      = q;
  return this;
}

bool
qt_chooser_widget_rep::set_type (const string& _type)
{
  if (_type == "directory") {
    type = _type;
    return true;
  } else if (_type == "generic") {
    nameFilter = "";
    type = _type;
    return true;
  }

  if (as_bool (call ("format?", _type))) {
    nameFilter = to_qstring (translate
                             (as_string (call ("format-get-name", _type))
                              * " file"));
  } else if (_type == "image") {
    nameFilter = to_qstring (translate ("Image file"));
  } else {
    if (DEBUG_STD)
      debug_widgets << "qt_chooser_widget: IGNORING unknown format "
                    << _type << LF;
    return false;
  }

  nameFilter += " (";
  object ret = call ("format-get-suffixes*", _type);
  array<object> suffixes = as_array_object (ret);
  if (N(suffixes) > 1)
    defaultSuffix = to_qstring (as_string (suffixes[1]));
  for (int i = 1; i < N(suffixes); ++i)
    nameFilter += " *." + to_qstring (as_string (suffixes[i]));
  nameFilter += " )";
  
  type = _type;
  return true;
}



/*! Actually displays the dialog with all the options set.
 * Uses a native dialog on Mac/Win and opens a custom dialog with image preview
 * for other platforms.
 */
void
qt_chooser_widget_rep::perform_dialog () {
  QString caption = to_qstring (win_title);
  c_string tmp (directory * "/" * file);
  QString path = QString::fromLocal8Bit (tmp);
  
#if (defined(Q_WS_MAC) )// || defined(Q_WS_WIN)) //at least windows Xp and 7 lack image preview, switch to custom dialog
  QFileDialog* dialog = new QFileDialog (NULL, caption, path);
#else
  QTMFileDialog*  dialog;
  QTMImageDialog* imgdialog = 0; // to avoid a dynamic_cast
  
  if (type == "image")
    dialog = imgdialog = new QTMImageDialog (NULL, caption, path);
  else
    dialog = new QTMFileDialog (NULL, caption, path);
#endif
  
  dialog->setViewMode (QFileDialog::Detail);
  if (type == "directory")
    dialog->setFileMode (QFileDialog::Directory);
  else if (type == "image" && !save)  // check !save just in case we support it
    dialog->setFileMode (QFileDialog::ExistingFile);
  else
    dialog->setFileMode (QFileDialog::AnyFile);

  if (save) {
    dialog->setDefaultSuffix (defaultSuffix);
    dialog->setAcceptMode (QFileDialog::AcceptSave);
    dialog->setLabelText (QFileDialog::Accept, to_qstring (translate ("Save")));
  }

#if (QT_VERSION >= 0x040400)
  if (type != "directory") {
    QStringList filters;
    if (nameFilter != "")
      filters << nameFilter;
    filters << to_qstring (translate ("All files (*)"));
    dialog->setNameFilters (filters);
  }
#endif

  dialog->updateGeometry();
  QSize   sz = dialog->sizeHint();
  QPoint pos = to_qpoint (position);
  QRect r;

  r.setSize (sz);
  r.moveCenter (pos);
  dialog->setGeometry (r);
  
  QStringList fileNames;
  file = "#f";
  if (dialog->exec ()) {
    fileNames = dialog->selectedFiles();
    if (fileNames.count() > 0) {
      url u = url_system (scm_unquote (from_qstring (fileNames.first())));
        // FIXME: charset detection in to_qstring() (if that hack is still there)
        // fails sometimes, so we bypass it to force the proper (?) conversions here.
      //QByteArray arr   = to_qstring (as_string (u)).toLocal8Bit ();
      QByteArray arr   = utf8_to_qstring (cork_to_utf8 (as_string (u))).toLocal8Bit ();
      const char* cstr = arr.constData ();
      string localname = string ((char*) cstr);
      file = "(system->url " * scm_quote (localname) * ")";
      if (type == "image") {
#if !defined(Q_WS_MAC) // && !defined(Q_WS_WIN)   //at least windows Xp and 7 lack image preview, switch to custom dialog
        file = "(list " * file * imgdialog->getParamsAsString () * ")"; //set image size from preview
#else //MacOs only now
        QPixmap pic (fileNames.first());
        string params;
          // HACK: which value should we choose here?
//Philippe: using	image_size (u,  w,  h); would make the behavior consistent across platforms.
        int ww = (get_current_editor()->get_page_width () / PIXEL) / 3;
        int  w = min (ww, pic.width()); // in windows Xp and 7 this does not give a valid size for eps or pdf images
        int  h = ((double) pic.height() / (double) pic.width()) * (double) w;   // no risk of division by zero here on invalid file?
        params << "\"" << from_qstring (QString ("%1px").arg (w)) << "\" "
               << "\"" << from_qstring (QString ("%1px").arg (h)) << "\" "
               << "\"" << "" << "\" "  // xps ??
               << "\"" << "" << "\"";   // yps ??
        file = "(list " * file * params * ")"; 
#endif
      }
    }
  }

  delete dialog;
  
  cmd ();
  if (!is_nil (quit)) quit ();
}
