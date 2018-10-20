import resolve from 'rollup-plugin-node-resolve';

export default {
  input: 'src/client.js',
  output: {
    file: 'dist/gen-browser.js',
    format: 'umd',
    name: 'GenBrowser'
  },
  plugins: [ resolve() ]
};
