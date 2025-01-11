export function validateAppServerConfig(contents: string): boolean {
    interface AppServerConfig {
        Metadata: {
            GeneratedAt: number,
            UpdatedAt: number,
            AppAPIPreferredVersion: number,
            AppVersion: number,
            IsOld: number,
            AdministerID: number,
        },

        Developer: {
            Name: string,
            ID: number
        },

        Votes: {
            Dislikes: number,
            Likes: number,
            Score: number,
            Favorites: number
        },

        Name: string,
        Title: string,
        DownloadCount: number,
        IconID: number,
        BlurredIcon: number,
        ShortDescription: string,
        LongDescription: string,
        InstallID: number,
        Type: string,
        Tags: string[]
    }

    const parsed: AppServerConfig = JSON.parse(contents);

    const expected: (keyof AppServerConfig | keyof AppServerConfig['Metadata'] | keyof AppServerConfig['Developer'] | keyof AppServerConfig['Votes'])[] = [
        'Metadata', 'Developer', 'Votes', 'Name', 'Title', 'DownloadCount', 'AppVersion', 'IconID', 'BlurredIcon', 'ShortDescription', 'LongDescription', 'InstallID', 'Type', 'Tags',
        'GeneratedAt', 'UpdatedAt', 'AppAPIPreferredVersion', 'IsOld', 'AdministerID',
        'Name', 'ID', 'Dislikes', 'Likes', 'Score', 'Favorites'
    ];

    let result: boolean = Object.keys(parsed).some(key => {
        if (!expected.includes(key as keyof AppServerConfig)) {
            console.error(`Bad key in app server config! Please remove: ${key}`);
            return true;
        }
        return false;
    });

    if (result) return false;
    return true;

}
