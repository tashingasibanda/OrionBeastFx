package com.orionbeastfx.alerts;
import android.content.*;
import org.json.*;
final class Store {
    static android.content.SharedPreferences prefs(Context c) { return c.getSharedPreferences("orion", 0); }
    static String topic(Context c) { return prefs(c).getString("topic", "OrionBeastFx"); }
    static synchronized JSONArray inbox(Context c) {
        try { return new JSONArray(prefs(c).getString("inbox", "[]")); }
        catch (JSONException e) { return new JSONArray(); }
    }
    static synchronized void save(Context c, JSONObject message, String topic) throws JSONException {
        JSONArray old = inbox(c), next = new JSONArray(); next.put(message);
        for (int i=0; i<Math.min(99, old.length()); i++) next.put(old.getJSONObject(i));
        prefs(c).edit().putString("inbox", next.toString()).putString("cursor:"+topic, message.getString("id")).commit();
    }
    static void status(Context c, String value) { prefs(c).edit().putString("status", value).apply(); }
}
