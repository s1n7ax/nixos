/** What the band shows, read once at session start. */
export type Welcome = {
  hour: number;
  date: string;
  where: string;
};

declare module "claude-code" {
  interface PluginState {
    welcome: { welcome: Welcome | null; isGreeted: boolean };
  }
}
