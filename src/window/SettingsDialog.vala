/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2013 Timm Bäder
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

[GtkTemplate (ui = "/org/baedert/corebird/ui/settings-dialog.ui")]
class SettingsDialog : Gtk.Dialog {
  private static const string DUMMY_SCREEN_NAME = "<Unnamed>";
  private MainWindow main_window;
  [GtkChild]
  private ListBox account_list;
  [GtkChild]
  private ToolButton add_account_button;
  [GtkChild]
  private ToolButton remove_account_button;
  [GtkChild]
  private Gtk.Stack account_info_stack;
  [GtkChild]
  private Switch on_new_mentions_switch;
  [GtkChild]
  private Switch on_new_followers_switch;
  [GtkChild]
  private Switch on_new_dms_switch;
  [GtkChild]
  private Switch inline_media_switch;
  [GtkChild]
  private Switch dark_theme_switch;
  [GtkChild]
  private ComboBoxText upload_provider_combobox;
  [GtkChild]
  private ComboBoxText on_new_tweets_combobox;
  [GtkChild]
  private Switch search_show_retweets_switch;

  public SettingsDialog(MainWindow? main_window = null, Corebird? application = null){
    this.main_window = main_window;
    this.application = application;
    this.title = "Corebird Settings";

    // General Page
    Settings.get ().bind ("upload-provider", upload_provider_combobox, "active-id",
                          SettingsBindFlags.DEFAULT);

    // Notifications Page
    Settings.get ().bind ("new-tweets-notify", on_new_tweets_combobox, "active-id",
                          SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("new-mentions-notify", on_new_mentions_switch, "active",
                          SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("new-followers-notify", on_new_followers_switch, "active",
                          SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("new-dms-notify", on_new_dms_switch, "active",
                          SettingsBindFlags.DEFAULT);

    // Interface page
    Settings.get ().bind ("show-inline-media", inline_media_switch, "active",
                          SettingsBindFlags.DEFAULT);
    Settings.get ().bind ("use-dark-theme", dark_theme_switch, "active",
                          SettingsBindFlags.DEFAULT);
    dark_theme_switch.notify["active"].connect (() => {
        message ("aa");
        Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = dark_theme_switch.active;
    });

    // Behaviour page
    Settings.get ().bind ("search-show-retweets", search_show_retweets_switch, "active",
                          SettingsBindFlags.DEFAULT);

    // General Page
    Settings.get ().bind ("upload-provider", upload_provider_combobox, "active_id",
                          SettingsBindFlags.DEFAULT);

    unowned SList<Account> accs = Account.list_accounts ();
    foreach (Account a in accs) {
      a.load_avatar ();
      account_list.add (new AccountListEntry (a));
      account_info_stack.add_named (new AccountInfoWidget (a, this.application), a.screen_name);
    }
    if (accs.length() > 0)
      account_list.select_row (account_list.get_row_at_index (0));
  }

  [GtkCallback]
  private void add_account_clicked () {
    Account dummy_acc = new Account(0, DUMMY_SCREEN_NAME, "<__>");
    Account.add_account (dummy_acc);
    var row = new AccountListEntry (dummy_acc);
    account_list.add (row);
    var create_widget = new AccountCreateWidget (dummy_acc);
    create_widget.result_received.connect (on_account_access);
    account_info_stack.add_named (create_widget, DUMMY_SCREEN_NAME);
    row.show_all ();
    account_list.select_row (row);
    create_widget.open_pin_request_site ();

    add_account_button.sensitive = false;
  }

  [GtkCallback]
  private void remove_account_clicked () {
    AccountListEntry entry = (AccountListEntry)account_list.get_selected_row ();
    if (entry.screen_name == DUMMY_SCREEN_NAME) {
      account_list.remove (entry);
      account_info_stack.remove (account_info_stack.get_visible_child ());
      Account.remove_account (DUMMY_SCREEN_NAME);
      add_account_button.sensitive = true;
    } else {
      var remove_dialog = new RemoveAccountDialog ();
      remove_dialog.remove_clicked.connect (() => {
        real_remove_account (entry);
        remove_dialog.destroy ();
      });
      remove_dialog.show ();
    }
  }

  [GtkCallback]
  private void account_list_selected () {
    ListBoxRow row = account_list.get_selected_row ();
    if (row == null) {
      remove_account_button.sensitive = false;
      return;
    }
    AccountListEntry entry = (AccountListEntry)row;
    account_info_stack.set_visible_child_name (entry.screen_name);
    remove_account_button.sensitive = true;
  }

  [GtkCallback]
  private void close_button_clicked () {
    Account.remove_account (DUMMY_SCREEN_NAME);
    destroy();
  }

  private void on_account_access (bool result, Account acc) {
    if (result) {
      account_info_stack.remove (account_info_stack.get_visible_child ());
      var acc_widget = new AccountInfoWidget (acc, this.application);
      account_info_stack.add_named (acc_widget, acc.screen_name);
      account_info_stack.set_visible_child_name (acc.screen_name);
      account_list.remove (account_list.get_selected_row ());
      var new_entry = new AccountListEntry (acc);
      account_list.add (new_entry);
      account_list.select_row (new_entry);
    } else {
      // In this case, the account was already present so we just remove the item again
      // the given accoun is then the already defined one.
      account_info_stack.remove (account_info_stack.get_visible_child ());
      account_list.remove (account_list.get_selected_row ());
      select_account (acc.screen_name);
    }
  }

  private void real_remove_account (AccountListEntry entry) {
    var acc_menu = (GLib.Menu)Corebird.account_menu;
    int64 acc_id = entry.account.id;
    FileUtils.remove (Utils.user_file ("accounts/$(acc_id).db"));
    FileUtils.remove (Utils.user_file ("accounts/$(acc_id).png"));
    FileUtils.remove (Utils.user_file ("accounts/$(acc_id)_small.png"));
    Corebird.db.exec (@"DELETE FROM `accounts` WHERE `id`='$(acc_id)';");
    account_info_stack.remove (account_info_stack.get_visible_child ());
    account_list.remove (entry);
    string[] startup_accounts = Settings.get ().get_strv ("startup-accounts");
    for (int i = 0; i < startup_accounts.length; i++)
      if (startup_accounts[i] == entry.account.screen_name) {
        string[] sa_new = new string[startup_accounts.length - 1];
        for (int x = 0; x < i; i++)
          sa_new[x] = startup_accounts[x];
        for (int x = i+1; x < startup_accounts.length; x++)
          sa_new[x] = startup_accounts[x];
        Settings.get ().set_strv ("startup-accounts", sa_new);
      }

    for (int i = 0; i < acc_menu.get_n_items (); i++){
      Variant item_name = acc_menu.get_item_attribute_value (i,
                                       "label", VariantType.STRING);
      if (item_name.get_string () == "@"+entry.account.screen_name) {
        acc_menu.remove (i);
        break;
      }
    }
    Account.remove_account (entry.account.screen_name);
    MainWindow acc_window;
    if (((Corebird)this.application).is_window_open_for_screen_name (
          entry.account.screen_name, out acc_window)) {
      acc_window.close ();
    }

  }

  private void select_account (string screen_name) {
    GLib.List<weak Widget> entries = account_list.get_children ();
    foreach (var entry in entries) {
      if (((AccountListEntry)entry).screen_name == screen_name) {
        account_list.select_row ((Gtk.ListBoxRow)entry);
        break;
      }
    }
  }
}
