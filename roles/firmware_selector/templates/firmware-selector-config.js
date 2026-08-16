/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

var config = {
    // list images on console that match no model
    listMissingImages: false,
    // see devices.js for different vendor model maps
    vendormodels: vendormodels,
    // set enabled categories of devices (see devices.js)
    enabled_device_categories: ["recommended", "ath10k_lowmem", "small_kernel_part", "legacy_target", "4_32", "8_32", "16_32"],
    // Display a checkbox that allows to display not recommended devices.
    // This only make sense if enabled_device_categories also contains not
    // recommended devices.
    recommended_toggle: true,
    // Optional link to an info page about no longer recommended devices
    recommended_info_link: 'https://freifunk-suedholstein.de/hardware/',
    // community prefix of the firmware images
    community_prefix: 'gluon-ffsh-',
    // firmware version regex
    version_regex: /-([\d]+\.[\d]+\.[\d]+([+-~][\d]+)?)[.-]/,
    // relative image paths and branch
    directories: {
        //'https://firmware.freifunk-suedholstein.de/dev/factory/': 'dev',
        //'https://firmware.freifunk-suedholstein.de/dev/sysupgrade/': 'dev',

        'https://firmware.freifunk-suedholstein.de/testing/factory/': 'testing',
        'https://firmware.freifunk-suedholstein.de/testing/sysupgrade/': 'testing',

        'https://firmware.freifunk-suedholstein.de/rc/factory/': 'rc',
        'https://firmware.freifunk-suedholstein.de/rc/sysupgrade/': 'rc',

        'https://firmware.freifunk-suedholstein.de/stable/factory/': 'stable',
        'https://firmware.freifunk-suedholstein.de/stable/sysupgrade/': 'stable',
    },
    // page title
    title: 'Firmware für Freifunk Südholstein',
    // branch descriptions shown during selection
    branch_descriptions: {
        stable: 'Wurde bereits getestet, sollte zuverlässig und stabil laufen.',
        rc: 'Ungetestet, die neueste version, kann Fehler enthalten. Nur für erfahrene Nutzer.',
        testing: 'Ungetestet, die neueste version, kann Fehler enthalten. Nur für erfahrene Nutzer.',
    },
    // recommended branch will be marked during selection
    recommended_branch: 'stable',
    // experimental branches (show a warning for these branches)
    experimental_branches: ['testing', 'rc'],
    // path to preview pictures directory
    preview_pictures: 'pictures/',
    // link to changelog
    changelog: 'https://freifunk-suedholstein.de/tag/firmware/'
};