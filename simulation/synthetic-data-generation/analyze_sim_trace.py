# https://cs.stanford.edu/people/ashton/pubs/twiral.pdf

import polars as pl
import argparse
import os
import sys

import matplotlib.pyplot as plt
plt.style.use('ggplot')

def propagation_actions_barplot(df: pl.DataFrame, n: int, filename: str) -> None:

    top_posts = df.head(n)

    plt.figure(figsize=(12, 6))

    plt.bar(
        top_posts["post_id"].cast(pl.String), 
        top_posts["count"], 
        color='#1DA1F2',
        edgecolor='black',
        alpha=0.9,
        label='Total Actions'
    )

    plt.title(f"Top {n} Most Viral Posts", fontsize=16)
    plt.xlabel("Post ID", fontsize=12)
    plt.ylabel("Number of Actions", fontsize=12)

    plt.xticks(rotation=45)
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.legend()

    plt.tight_layout()
    plt.savefig(f"img/top_posts_{n}_{filename}.png", dpi=300)
    plt.close()

def histogram_power_law(df: pl.DataFrame, filename: str) -> None:
    plt.figure(figsize=(10, 6))

    plt.hist(
        df["count"], 
        bins=50, 
        color='#FF7F50', 
        edgecolor='black', 
        alpha=0.8,
        log=True,
        label='Frequency of Virality'
    )

    plt.title("Distribution of Post Engagement", fontsize=16)
    plt.xlabel("Number of Actions (Likes, Reposts, etc.)", fontsize=12)
    plt.ylabel("Number of Posts (Log Scale)", fontsize=12)

    plt.grid(axis='both', linestyle='--', alpha=0.3)
    plt.legend()

    plt.tight_layout()
    plt.savefig(f"img/virality_distribution_{filename}.png", dpi=300)
    plt.close()


def top_n_posts_growthrate(n: int, df: pl.DataFrame, df_hist: pl.DataFrame, filename: str) -> None:
    top_n_ids = df_hist.head(n)["post_id"].to_list()

    plt.figure(figsize=(12, 7))

    for rank, post_id in enumerate(top_n_ids, start=1):
        
        post_times = (
            df.filter(
                (pl.col("post_id") == post_id) & 
                (pl.col("type") != "nothing")
            )
            .select("time")
            .sort("time")
            .to_series() # an array for Matplotlib
        )
        
        cumulative_actions = range(1, len(post_times) + 1)
        
        plt.step(
            post_times, 
            cumulative_actions, 
            where='post',
            linewidth=2.5,
            label=f"Rank {rank}: Post {post_id}"
        )

    plt.title("Growth Trajectory of the Top 3 Viral Posts", fontsize=16, fontweight='bold')
    plt.xlabel("Simulation Time (t)", fontsize=12)
    plt.ylabel("Cumulative Interactions", fontsize=12)

    plt.grid(True, linestyle='--', alpha=0.6)
    plt.legend(fontsize=12, loc="upper left")

    plt.tight_layout()
    plt.savefig(f"img/viral_growth_trajectory_{filename}.png", dpi=300)
    plt.close()


def main(filename: str) -> None:
    print("Hello from main")
    
    df = pl.read_ndjson(filename)

    hist_data = (
        df.filter(pl.col("type").is_in(["repost"]))
        .group_by("post_id")                      
        .len(name="count")                        
        .sort("count", descending=True)           
    )

    print(hist_data)
   
    filename = filename.split('/')[-1]
    propagation_actions_barplot(hist_data, 20, filename)
    print("Num of impressions genrated")
    propagation_actions_barplot(hist_data, 2000, filename)
    propagation_actions_barplot(hist_data, 10000, filename)
    histogram_power_law(hist_data, filename)
    print("Power law generated")
    top_n_posts_growthrate(4, df, hist_data, filename)
    print("Growth historic of posts generated")


if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(
        prog="data analysis",
        description="Analysis the trace",
        epilog="Help",
    )

    parser.add_argument("filename")
    args = parser.parse_args()

    if (not os.path.exists(args.filename)):
        print("The file provided does not exist")
        sys.exit(0)

    main(args.filename)
