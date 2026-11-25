#!/usr/bin/env ucode
'use strict';

import { lsdir, popen, stat } from 'fs';
import { log } from 'math';

function run_ethtool(cmd) {
	let proc = popen(cmd, 'r');

	if (!proc)
		return null;

	let out = proc.read('all');

	proc.close();

	if (!out)
		return null;

	let json_data = null;
	let bracket_end = rindex(out, ']');
	if (bracket_end >= 0) {
		let json_str = substr(out, 0, bracket_end + 1);
		try {
			json_data = json(trim(json_str));
		} catch (e) {}
	}

	if (!json_data) {
		try {
			json_data = json(trim(out));
		} catch (e) {}
	}

	if (!json_data)
		return null;

	return { data: json_data, raw: out };
}

function shellquote(s) {
	return `'${replace(s, "'", "'\\''")}'`;
}

function mw_to_dbm(mw) {
	if (mw == null || mw <= 0)
		return null;

	return 10 * log(mw) / log(10);
}

function parse_ethtool_json(eth_obj, iface) {
	let eth_data = eth_obj.data;
	let raw = eth_obj.raw;

	let data = null;

	if (type(eth_data) == 'array' && length(eth_data) > 0)
		data = eth_data[0];
	else if (type(eth_data) == 'object')
		data = eth_data;
	else
		return null;

	let identifier = data.identifier_description || null;

	if (!identifier)
		return null;

	let connector = data.connector_description || null;

	let wavelength = data.laser_wavelength != null ?
		+data.laser_wavelength : null;

	let vendor_oui = type(data.vendor_oui) == 'array' ?
		sprintf('%02x:%02x:%02x',
			data.vendor_oui[0],
			data.vendor_oui[1],
			data.vendor_oui[2]) : null;

	let transceiver_types = [];

	if (data.transceiver_type)
		push(transceiver_types, data.transceiver_type);

	let bias = data.laser_tx_bias_current;
	let is_multi_ch = type(bias) == 'array';
	let ch_count = is_multi_ch ? min(length(bias), 4) : 1;

	let diag = {};

	diag.temperature_c = data.module_temperature_measurement != null ?
		+data.module_temperature_measurement : null;
	diag.voltage_v = data.module_voltage_measurement != null ?
		+data.module_voltage_measurement : null;

	if (is_multi_ch) {
		for (let ch = 0; ch < ch_count; ch++) {
			let ci = ch + 1;

			diag[`bias_current_ma_ch${ci}`] =
				bias[ch] != null ? +bias[ch] : null;

			let tx_arr = data.transmit_avg_optical_power;
			let tx_mw = (type(tx_arr) == 'array' &&
				tx_arr[ch] != null) ? +tx_arr[ch] : null;

			diag[`tx_power_mw_ch${ci}`] = tx_mw;
			diag[`tx_power_dbm_ch${ci}`] = mw_to_dbm(tx_mw);

			let rx_obj = data.rx_power;
			let rx_arr = (type(rx_obj) == 'object' &&
				type(rx_obj.values) == 'array') ?
				rx_obj.values : null;

			let rx_mw = (rx_arr != null && rx_arr[ch] != null) ?
				+rx_arr[ch] : null;

			diag[`rx_power_mw_ch${ci}`] = rx_mw;
			diag[`rx_power_dbm_ch${ci}`] = mw_to_dbm(rx_mw);
		}

		diag.bias_current_ma = diag.bias_current_ma_ch1;
		diag.tx_power_mw     = diag.tx_power_mw_ch1;
		diag.tx_power_dbm    = diag.tx_power_dbm_ch1;
		diag.rx_power_mw     = diag.rx_power_mw_ch1;
		diag.rx_power_dbm    = diag.rx_power_dbm_ch1;
	} else {
		diag.bias_current_ma = bias != null ? +bias : null;

		let tx_val = data.transmit_avg_optical_power;

		diag.tx_power_mw  = tx_val != null ? +tx_val : null;
		diag.tx_power_dbm = mw_to_dbm(tx_val != null ? +tx_val : null);

		let rx_obj = data.rx_power;
		let rx_val = (type(rx_obj) == 'object') ? rx_obj.value : null;

		diag.rx_power_mw  = rx_val != null ? +rx_val : null;
		diag.rx_power_dbm = mw_to_dbm(rx_val != null ? +rx_val : null);
	}

	/* Fallback to text parsing for SFP modules where ethtool 6.x outputs DOM as text */
	if (raw) {
		let m_temp = match(raw, /Module temperature\s*:\s*([0-9.-]+)\s*degrees C/);
		if (m_temp && diag.temperature_c == null)
			diag.temperature_c = +m_temp[1];

		let m_volt = match(raw, /Module voltage\s*:\s*([0-9.]+)\s*V/);
		if (m_volt && diag.voltage_v == null)
			diag.voltage_v = +m_volt[1];

		let m_bias = match(raw, /Laser bias current\s*:\s*([0-9.]+)\s*mA/);
		if (m_bias && diag.bias_current_ma == null)
			diag.bias_current_ma = +m_bias[1];

		let m_tx = match(raw, /Laser output power\s*:\s*([0-9.]+)\s*mW\s*\/\s*([0-9.-]+)\s*dBm/);
		if (m_tx && diag.tx_power_mw == null) {
			diag.tx_power_mw = +m_tx[1];
			diag.tx_power_dbm = +m_tx[2];
		}

		let m_rx = match(raw, /Receiver.*optical power\s*:\s*([0-9.]+)\s*mW\s*\/\s*([0-9.-]+)\s*dBm/);
		if (m_rx && diag.rx_power_mw == null) {
			diag.rx_power_mw = +m_rx[1];
			diag.rx_power_dbm = +m_rx[2];
		}
	}

	const alarm_map = {
		'laser_bias_current_high_alarm':  'tx_bias_high',
		'laser_output_power_high_alarm': 'tx_power_high',
		'laser_tx_power_high_alarm':     'tx_power_high',
		'laser_bias_current_low_alarm':   'tx_bias_low',
		'laser_output_power_low_alarm':  'tx_power_low',
		'laser_tx_power_low_alarm':      'tx_power_low',
		'module_temperature_high_alarm':  'temp_high',
		'module_temperature_low_alarm':   'temp_low',
		'module_voltage_high_alarm':      'voltage_high',
		'module_voltage_low_alarm':       'voltage_low',
		'laser_rx_power_high_alarm':      'rx_power_high',
		'laser_rx_power_low_alarm':       'rx_power_low',
	};

	const warning_map = {
		'laser_bias_current_high_warning':  'tx_bias_high',
		'laser_output_power_high_warning': 'tx_power_high',
		'laser_tx_power_high_warning':     'tx_power_high',
		'laser_bias_current_low_warning':   'tx_bias_low',
		'laser_output_power_low_warning':  'tx_power_low',
		'laser_tx_power_low_warning':      'tx_power_low',
		'module_temperature_high_warning':  'temp_high',
		'module_temperature_low_warning':   'temp_low',
		'module_voltage_high_warning':      'voltage_high',
		'module_voltage_low_warning':       'voltage_low',
		'laser_rx_power_high_warning':      'rx_power_high',
		'laser_rx_power_low_warning':       'rx_power_low',
	};

	function map_flags(src, map) {
		let out = {};

		for (let json_key, out_key in map) {
			let val = src[json_key];

			if (val == null)
				continue;

			if (type(val) == 'array') {
				let has = false;

				for (let v in val) {
					if (v) {
						has = true;
						break;
					}
				}

				out[out_key] = has;
			} else {
				out[out_key] = !!val;
			}
		}

		return out;
	}

	let alarms   = map_flags(data, alarm_map);
	let warnings = map_flags(data, warning_map);

	function get_thr(obj, key) {
		if (type(obj) != 'object')
			return null;

		return obj[key] != null ? +obj[key] : null;
	}

	let thresholds = {};
	const thr_map = {
		'module_temperature': { h: 'temp_high_c',       l: 'temp_low_c'       },
		'module_voltage':     { h: 'voltage_high_v',     l: 'voltage_low_v'    },
		'laser_bias_current': { h: 'tx_bias_high_ma',    l: 'tx_bias_low_ma'   },
		'laser_output_power': { h: 'tx_power_high_mw',   l: 'tx_power_low_mw'  },
		'laser_rx_power':     { h: 'rx_power_high_mw',   l: 'rx_power_low_mw'  },
	};

	for (let src_key, out_keys in thr_map) {
		let obj = data[src_key];

		if (type(obj) == 'object') {
			thresholds[out_keys.h] = get_thr(obj, 'high_alarm_threshold');
			thresholds[out_keys.l] = get_thr(obj, 'low_alarm_threshold');
		}
	}

	let vendor_name = data.vendor_name || null;
	let vendor_pn   = data.vendor_pn  || null;
	let vendor_rev  = data.vendor_rev || null;
	let vendor_sn   = data.vendor_sn  || null;
	let date_code   = data.date_code  || null;

	/* Workaround for Nokia/Alcatel-Lucent G-010S-P I2C 0x50 bit-drop under active link */
	if (iface == 'sfp-wan' && (
		(vendor_name && (index(vendor_name, '@') >= 0 || index(vendor_name, '_') >= 0)) ||
		(vendor_pn && (index(vendor_pn, '@') >= 0 || index(vendor_pn, '_') >= 0)) ||
		(wavelength != null && wavelength > 0 && wavelength < 800)
	)) {
		vendor_name = 'ALCATELLUCENT';
		vendor_oui  = '00:19:ba';
		vendor_pn   = 'G010SP';
		vendor_rev  = '10';
		vendor_sn   = (vendor_sn && index(vendor_sn, '@') < 0 && index(vendor_sn, '_') < 0) ? vendor_sn : 'ALCL00000000';
		date_code   = '170707';
		wavelength  = 1310;
		if (length(transceiver_types) == 0)
			push(transceiver_types, '2500BASE-X / GPON ONU (1310nm SM)');
	}

	return {
		iface, present: true,
		identifier, connector, wavelength,
		vendor_name,
		vendor_oui,
		vendor_pn,
		vendor_rev,
		vendor_sn,
		date_code,
		transceiver_type: transceiver_types,
		diagnostics:  diag,
		alarms, warnings, thresholds,
	};
}

function rpc_list() {
	let result = [];
	let names  = lsdir('/sys/class/net/');

	if (!names)
		return { result };

	for (let name in names) {
		if (!stat('/sys/class/net/' + name + '/device'))
			continue;

		let out = run_ethtool(
			'/usr/sbin/ethtool --json -m ' +
			shellquote(name) +
			' 2>/dev/null');

		if (out) {
			try {
				let parsed = parse_ethtool_json(out, name);
				if (parsed)
					push(result, parsed);
			} catch (e) {}
		}
	}

	return { result };
}

const methods = {
	list: { call: () => rpc_list() },
};

return { 'luci.sfp-info': methods };
