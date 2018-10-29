import resolve from 'rollup-plugin-node-resolve';

export default {
  input: 'lib/client.js',
  output: {
    file: 'dist/gen_browser.js',
    format: 'umd',
    name: 'GenBrowser'
  },
  plugins: [ resolve() ]
};
