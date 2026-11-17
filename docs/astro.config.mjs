// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://ffsh.github.io',
	base: '/ansible',
	integrations: [
		starlight({
			title: 'Freifunk Südholstein Ansible',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/ffsh/ansible' }],
			sidebar: [
				{
					label: 'Guides',
					items: [{ autogenerate: { directory: 'guides' } }],
				},
				{
					label: 'Reference',
					items: [{ autogenerate: { directory: 'reference' } }],
				},
			],
		}),
	],
});
