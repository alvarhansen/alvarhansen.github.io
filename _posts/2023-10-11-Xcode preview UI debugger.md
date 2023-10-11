---
layout: post
title: Debugging Xcode preview with Xcode UI debugger
---

Yes, you can actually use Xcode UI debugger to debug your SwiftUI previews. It's
not as easy as it should be, but it's still quite simple.

TL;DR: Attach to Xcode preview simulator process.

1. Open your SwiftUI preview
![Screenshot 2023-10-11 at 10.24.43.png](/assets/images/Screenshot 2023-10-11 at 10.24.43.png)
2. Go to Debug -> Attach to Process
3. Under "Likely targets", select the process with name of your preview.
![Screenshot 2023-10-11 at 10.26.38 - 2.png](/assets/images/Screenshot 2023-10-11 at 10.26.38 - 2.png)
4. You can now use Xcode to attach UI debugger to your preview.
![Screenshot 2023-10-11 at 10.27.39 - 2.png](/assets/images/Screenshot 2023-10-11 at 10.27.39 - 2.png)
5. Success! You can now inspect your preview.
![Screenshot 2023-10-11 at 10.27.55.png](/assets/images/Screenshot 2023-10-11 at 10.27.55.png)
