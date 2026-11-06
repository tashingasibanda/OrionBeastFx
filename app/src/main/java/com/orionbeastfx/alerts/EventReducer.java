package com.orionbeastfx.alerts;
import org.json.*;
import java.time.LocalDate;
/** Data contract only: no market guesses or sample records. */
final class EventReducer {
    static JSONObject apply(JSONObject current, JSONObject e, long time) throws JSONException {
        JSONObject out = new JSONObject(current.toString());
        String type=e.optString("type");
        if ("symbol".equals(type)) {
            JSONObject symbols=out.optJSONObject("symbols");
            if(symbols==null) symbols=new JSONObject();
            update(symbols,e,time); out.put("symbols",symbols);
        } else if ("snapshot".equals(type)) {
            if(time<out.optLong("snapshot_time",0)) return out;
            JSONArray list=e.optJSONArray("symbols");
            if(list==null) throw new JSONException("snapshot needs symbols array");
            JSONObject symbols=new JSONObject();
            for(int i=0;i<list.length();i++) update(symbols,list.getJSONObject(i),time);
            JSONObject previous=out.optJSONObject("symbols");
            // Do not let a replayed snapshot overwrite more recent symbol changes.
            if(previous!=null) for(java.util.Iterator<String> k=previous.keys();k.hasNext();) {
                String key=k.next(); JSONObject row=previous.getJSONObject(key);
                if(row.optLong("time")>time) symbols.put(key,row);
            }
            out.put("symbols",symbols); out.put("snapshot_time",time);
        } else if ("summary".equals(type)) {
            String date=e.getString("date");
            try { LocalDate.parse(date); } catch(Exception ex) { throw new JSONException("date must be YYYY-MM-DD"); }
            JSONObject summaries=out.optJSONObject("summaries"); if(summaries==null) summaries=new JSONObject();
            JSONObject previous=summaries.optJSONObject(date);
            if(previous!=null && previous.optLong("time")>time) return out;
            JSONObject s=new JSONObject(); s.put("date",date); s.put("time",time);
            if(e.has("trades")) {
                double n=e.getDouble("trades"); if(n<0 || n!=Math.floor(n) || !Double.isFinite(n)) throw new JSONException("invalid trades");
                s.put("trades",n);
            }
            if(e.has("win_rate")) { double n=e.getDouble("win_rate"); if(!Double.isFinite(n)||n<0||n>100) throw new JSONException("win_rate must be 0..100"); s.put("win_rate",n); }
            if(e.has("net_r")) { double n=e.getDouble("net_r"); if(!Double.isFinite(n)) throw new JSONException("invalid net_r"); s.put("net_r",n); }
            summaries.put(date,s); out.put("summaries",summaries);
        } else if (!"heartbeat".equals(type)) throw new JSONException("Unknown structured event type");
        out.put("last_ea",Math.max(time,out.optLong("last_ea",0)));
        return out;
    }
    static void update(JSONObject symbols, JSONObject e, long time) throws JSONException {
        String name=e.getString("symbol").trim();
        if(name.isEmpty()||name.length()>80) throw new JSONException("invalid symbol");
        String state=e.getString("state").toLowerCase(java.util.Locale.ROOT);
        if(!state.equals("watch")&&!state.equals("standby")&&!state.equals("remove")) throw new JSONException("state must be watch, standby or remove");
        JSONObject previous=symbols.optJSONObject(name);
        if(previous!=null && previous.optLong("time")>time) return;
        // Keep remove tombstones to prevent old replayed messages resurrecting a symbol.
        JSONObject row=new JSONObject(); row.put("symbol",name);row.put("state",state);row.put("time",time);
        row.put("reason",e.optString("reason",""));row.put("timeframe",e.optString("timeframe",""));
        symbols.put(name,row);
    }
}
